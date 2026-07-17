from lockedin_backend.models import UsageDailyAppAggregate, UsageDailyCategoryAggregate, UsageEvent

from datetime import datetime, timedelta, timezone


def test_usage_ingestion_persists_events_and_aggregates(client, db_session) -> None:
    response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                {
                    "sourceEventId": "android:instagram:1",
                    "appId": "com.instagram.android",
                    "appName": "Instagram",
                    "category": "Social",
                    "startedAt": "2026-06-07T12:00:00Z",
                    "endedAt": "2026-06-07T12:30:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                }
            ]
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "receivedCount": 1,
        "createdCount": 1,
        "duplicateCount": 0,
    }

    stored_events = db_session.query(UsageEvent).all()
    stored_app_aggregates = db_session.query(UsageDailyAppAggregate).all()
    stored_category_aggregates = db_session.query(UsageDailyCategoryAggregate).all()

    assert len(stored_events) == 1
    assert stored_events[0].duration_minutes == 30
    assert len(stored_app_aggregates) == 1
    assert stored_app_aggregates[0].app_id == "com.instagram.android"
    assert stored_app_aggregates[0].total_minutes == 30
    assert len(stored_category_aggregates) == 1
    assert stored_category_aggregates[0].category == "Social"
    assert stored_category_aggregates[0].total_minutes == 30


def test_duplicate_source_event_id_is_idempotent(client, db_session) -> None:
    payload = {
        "events": [
            {
                "sourceEventId": "android:youtube:1",
                "appId": "com.youtube.android",
                "appName": "YouTube",
                "category": "Entertainment",
                "startedAt": "2026-06-07T12:00:00Z",
                "endedAt": "2026-06-07T12:45:00Z",
                "timezone": "Asia/Ho_Chi_Minh",
            }
        ]
    }

    first_response = client.post("/api/v1/usage/events", json=payload)
    second_response = client.post("/api/v1/usage/events", json=payload)

    assert first_response.status_code == 200
    assert second_response.status_code == 200
    assert second_response.json() == {
        "receivedCount": 1,
        "createdCount": 0,
        "duplicateCount": 1,
    }
    assert db_session.query(UsageEvent).count() == 1
    assert db_session.query(UsageDailyAppAggregate).one().total_minutes == 45


def test_usage_ingestion_splits_local_day_aggregates_at_timezone_boundary(
    client, db_session
) -> None:
    response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                {
                    "sourceEventId": "android:instagram:boundary",
                    "appId": "com.instagram.android",
                    "appName": "Instagram",
                    "category": "Social",
                    "startedAt": "2026-06-07T16:30:00Z",
                    "endedAt": "2026-06-07T17:30:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                }
            ]
        },
    )

    assert response.status_code == 200

    aggregates = db_session.query(UsageDailyCategoryAggregate).order_by(
        UsageDailyCategoryAggregate.usage_date.asc()
    ).all()

    assert [(aggregate.usage_date.isoformat(), aggregate.total_minutes) for aggregate in aggregates] == [
        ("2026-06-07", 30),
        ("2026-06-08", 30),
    ]


def test_usage_ingestion_validation_errors(client) -> None:
    response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                {
                    "sourceEventId": "bad",
                    "appId": "com.instagram.android",
                    "appName": "Instagram",
                    "startedAt": "2026-06-07T12:30:00Z",
                    "endedAt": "2026-06-07T12:00:00Z",
                    "timezone": "Invalid/Timezone",
                }
            ]
        },
    )

    assert response.status_code == 422


def _event_payload(
    source_event_id: str,
    started_at: datetime,
    ended_at: datetime,
    *,
    app_id: str = "com.google.android.youtube",
) -> dict:
    return {
        "sourceEventId": source_event_id,
        "appId": app_id,
        "appName": "YouTube",
        "category": "Entertainment",
        "startedAt": started_at.isoformat(),
        "endedAt": ended_at.isoformat(),
        "timezone": "UTC",
    }


def test_usage_ingestion_rejects_overlong_future_and_stale_events(client) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    invalid_events = [
        _event_payload("overlong", now - timedelta(hours=7), now),
        _event_payload(
            "future",
            now + timedelta(minutes=10),
            now + timedelta(minutes=11),
        ),
        _event_payload(
            "stale",
            now - timedelta(days=91, minutes=1),
            now - timedelta(days=91),
        ),
    ]

    for event in invalid_events:
        response = client.post("/api/v1/usage/events", json={"events": [event]})
        assert response.status_code == 422


def test_usage_ingestion_rejects_batches_over_one_hundred_events(client) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    events = [
        _event_payload(
            f"event-{index}",
            now - timedelta(minutes=202 - index * 2),
            now - timedelta(minutes=201 - index * 2),
        )
        for index in range(101)
    ]

    response = client.post("/api/v1/usage/events", json={"events": events})

    assert response.status_code == 422


def test_usage_ingestion_rejects_overlapping_same_app_intervals(client) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                _event_payload("overlap-1", now - timedelta(minutes=10), now - timedelta(minutes=5)),
                _event_payload("overlap-2", now - timedelta(minutes=7), now - timedelta(minutes=2)),
            ]
        },
    )

    assert response.status_code == 422


def test_usage_ingestion_rejects_overlap_with_stored_event(client, db_session) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    first = _event_payload("stored-1", now - timedelta(minutes=10), now - timedelta(minutes=5))
    overlapping = _event_payload("stored-2", now - timedelta(minutes=7), now - timedelta(minutes=2))

    assert client.post("/api/v1/usage/events", json={"events": [first]}).status_code == 200
    response = client.post("/api/v1/usage/events", json={"events": [overlapping]})

    assert response.status_code == 409
    assert db_session.query(UsageEvent).count() == 1


def test_partial_events_round_once_after_exact_seconds_are_summed(client, db_session) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                _event_payload("partial-1", now - timedelta(seconds=30), now - timedelta(seconds=20)),
                _event_payload("partial-2", now - timedelta(seconds=20), now),
            ]
        },
    )

    assert response.status_code == 200
    assert db_session.query(UsageDailyAppAggregate).one().total_minutes == 1
    assert db_session.query(UsageDailyCategoryAggregate).one().total_minutes == 1


def test_rebuild_repairs_derived_aggregates_without_deleting_raw_events(client, db_session) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    event = _event_payload("repair-1", now - timedelta(minutes=30), now)
    assert client.post("/api/v1/usage/events", json={"events": [event]}).status_code == 200
    aggregate = db_session.query(UsageDailyAppAggregate).one()
    aggregate.total_minutes = 999
    db_session.commit()

    response = client.post("/api/v1/usage/aggregates/rebuild")

    assert response.status_code == 200
    assert response.json()["eventCount"] == 1
    assert db_session.query(UsageEvent).count() == 1
    assert db_session.query(UsageDailyAppAggregate).one().total_minutes == 30
