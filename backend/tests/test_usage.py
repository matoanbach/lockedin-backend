from lockedin_backend.models import UsageDailyAppAggregate, UsageDailyCategoryAggregate, UsageEvent


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
