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


def _recent_midday_utc() -> datetime:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    midday = now.replace(hour=12, minute=0, second=0)
    return midday if midday <= now else midday - timedelta(days=1)


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


def test_usage_ingestion_clips_overlap_with_stored_event(client, db_session) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    first = _event_payload("stored-1", now - timedelta(minutes=10), now - timedelta(minutes=5))
    overlapping = _event_payload("stored-2", now - timedelta(minutes=7), now - timedelta(minutes=2))

    assert client.post("/api/v1/usage/events", json={"events": [first]}).status_code == 200
    response = client.post("/api/v1/usage/events", json={"events": [overlapping]})

    assert response.status_code == 200
    assert response.json() == {
        "receivedCount": 1,
        "createdCount": 1,
        "duplicateCount": 0,
    }
    stored = db_session.query(UsageEvent).order_by(UsageEvent.started_at.asc()).all()
    assert len(stored) == 2
    assert stored[1].source_event_id == "stored-2"
    assert stored[1].started_at == (now - timedelta(minutes=5)).replace(tzinfo=None)
    assert stored[1].ended_at == (now - timedelta(minutes=2)).replace(tzinfo=None)


def test_usage_ingestion_treats_fully_covered_event_as_duplicate(client, db_session) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    stored = _event_payload("covered-1", now - timedelta(minutes=10), now)
    covered = _event_payload(
        "covered-2",
        now - timedelta(minutes=8),
        now - timedelta(minutes=2),
    )

    assert client.post("/api/v1/usage/events", json={"events": [stored]}).status_code == 200
    response = client.post("/api/v1/usage/events", json={"events": [covered]})

    assert response.status_code == 200
    assert response.json() == {
        "receivedCount": 1,
        "createdCount": 0,
        "duplicateCount": 1,
    }
    assert db_session.query(UsageEvent).count() == 1


def test_usage_ingestion_splits_around_multiple_stored_intervals(client, db_session) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    first = _event_payload(
        "split-existing-1",
        now - timedelta(minutes=10),
        now - timedelta(minutes=8),
    )
    second = _event_payload(
        "split-existing-2",
        now - timedelta(minutes=6),
        now - timedelta(minutes=4),
    )
    recovery = _event_payload(
        "split-recovery",
        now - timedelta(minutes=12),
        now - timedelta(minutes=2),
    )

    assert client.post("/api/v1/usage/events", json={"events": [first]}).status_code == 200
    assert client.post("/api/v1/usage/events", json={"events": [second]}).status_code == 200
    response = client.post("/api/v1/usage/events", json={"events": [recovery]})

    assert response.status_code == 200
    assert response.json()["createdCount"] == 1
    stored = db_session.query(UsageEvent).order_by(UsageEvent.started_at.asc()).all()
    assert len(stored) == 5
    assert sum(event.duration_minutes for event in stored) == 10
    assert len({event.source_event_id for event in stored}) == 5

    retry = client.post("/api/v1/usage/events", json={"events": [recovery]})
    assert retry.status_code == 200
    assert retry.json()["duplicateCount"] == 1
    assert db_session.query(UsageEvent).count() == 5


def test_partial_events_keep_zero_completed_aggregate_minutes(client, db_session) -> None:
    now = _recent_midday_utc()
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
    assert db_session.query(UsageDailyAppAggregate).one().total_minutes == 0
    assert db_session.query(UsageDailyCategoryAggregate).one().total_minutes == 0


def test_two_hundred_seconds_store_three_completed_aggregate_minutes(
    client, db_session
) -> None:
    now = _recent_midday_utc()
    response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                _event_payload(
                    "two-hundred-seconds",
                    now - timedelta(seconds=200),
                    now,
                )
            ]
        },
    )

    assert response.status_code == 200
    assert db_session.query(UsageEvent).one().duration_minutes == 4
    assert db_session.query(UsageDailyAppAggregate).one().total_minutes == 3
    assert db_session.query(UsageDailyCategoryAggregate).one().total_minutes == 3


def test_rebuild_repairs_derived_aggregates_without_deleting_raw_events(
    client, operator_client, db_session
) -> None:
    now = _recent_midday_utc()
    event = _event_payload("repair-1", now - timedelta(minutes=30), now)
    assert client.post("/api/v1/usage/events", json={"events": [event]}).status_code == 200
    aggregate = db_session.query(UsageDailyAppAggregate).one()
    aggregate.total_minutes = 999
    db_session.commit()

    response = operator_client.post("/api/v1/usage/aggregates/rebuild")

    assert response.status_code == 200
    assert response.json()["eventCount"] == 1
    assert db_session.query(UsageEvent).count() == 1
    assert db_session.query(UsageDailyAppAggregate).one().total_minutes == 30
