import lockedin_backend.services.analytics_service as analytics_service_module


def test_dashboard_analytics_returns_zero_state_when_empty(client, monkeypatch) -> None:
    monkeypatch.setattr(
        analytics_service_module,
        "current_utc_now",
        lambda: analytics_service_module.datetime(2026, 6, 8, 12, 0, tzinfo=analytics_service_module.timezone.utc),
    )

    response = client.get("/api/v1/analytics/dashboard")

    assert response.status_code == 200
    assert response.json() == {
        "todayTotalMinutes": 0,
        "categoryBreakdown": [],
        "weeklyUsageHours": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        "weeklyTotalMinutes": 0,
        "deltaFromYesterdayPercent": 0,
    }


def test_dashboard_trends_and_weekly_summary_are_db_backed(client, monkeypatch) -> None:
    monkeypatch.setattr(
        analytics_service_module,
        "current_utc_now",
        lambda: analytics_service_module.datetime(2026, 6, 8, 12, 0, tzinfo=analytics_service_module.timezone.utc),
    )

    ingestion_response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                {
                    "sourceEventId": "day-1",
                    "appId": "com.instagram.android",
                    "appName": "com.instagram.android",
                    "category": "Other",
                    "startedAt": "2026-06-02T13:00:00Z",
                    "endedAt": "2026-06-02T14:00:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "day-2",
                    "appId": "com.youtube.android",
                    "appName": "com.youtube.android",
                    "category": "Other",
                    "startedAt": "2026-06-03T12:30:00Z",
                    "endedAt": "2026-06-03T13:00:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "day-3",
                    "appId": "com.instagram.android",
                    "appName": "Instagram",
                    "category": "Social",
                    "startedAt": "2026-06-04T14:00:00Z",
                    "endedAt": "2026-06-04T15:30:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "day-4",
                    "appId": "com.spotify.music",
                    "appName": "Spotify",
                    "category": "Entertainment",
                    "startedAt": "2026-06-05T15:00:00Z",
                    "endedAt": "2026-06-05T15:45:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "day-5",
                    "appId": "com.instagram.android",
                    "appName": "Instagram",
                    "category": "Social",
                    "startedAt": "2026-06-06T12:00:00Z",
                    "endedAt": "2026-06-06T12:30:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "day-6",
                    "appId": "com.youtube.android",
                    "appName": "YouTube",
                    "category": "Entertainment",
                    "startedAt": "2026-06-07T12:15:00Z",
                    "endedAt": "2026-06-07T13:00:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "day-7",
                    "appId": "com.instagram.android",
                    "appName": "Instagram",
                    "category": "Social",
                    "startedAt": "2026-06-08T13:30:00Z",
                    "endedAt": "2026-06-08T14:30:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "prev-week-1",
                    "appId": "com.instagram.android",
                    "appName": "Instagram",
                    "category": "Social",
                    "startedAt": "2026-05-26T13:00:00Z",
                    "endedAt": "2026-05-26T18:00:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "prev-week-2",
                    "appId": "com.youtube.android",
                    "appName": "YouTube",
                    "category": "Entertainment",
                    "startedAt": "2026-05-27T13:00:00Z",
                    "endedAt": "2026-05-27T17:00:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "prev-week-3",
                    "appId": "com.spotify.music",
                    "appName": "Spotify",
                    "category": "Entertainment",
                    "startedAt": "2026-05-28T13:00:00Z",
                    "endedAt": "2026-05-28T17:00:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
            ]
        },
    )

    assert ingestion_response.status_code == 200

    dashboard_response = client.get("/api/v1/analytics/dashboard")
    trends_response = client.get("/api/v1/analytics/trends")
    weekly_summary_response = client.get("/api/v1/analytics/weekly-summary")

    assert dashboard_response.status_code == 200
    assert dashboard_response.json() == {
        "todayTotalMinutes": 60,
        "categoryBreakdown": [
            {
                "name": "Social & Messaging",
                "minutes": 60,
                "durationMilliseconds": 3_600_000,
                "apps": [
                    {
                        "appId": "com.instagram.android",
                        "appName": "Instagram",
                        "minutes": 60,
                        "durationMilliseconds": 3_600_000,
                    }
                ],
            }
        ],
        "weeklyUsageHours": [1.0, 0.5, 1.5, 0.8, 0.5, 0.8, 1.0],
        "weeklyTotalMinutes": 360,
        "deltaFromYesterdayPercent": 33,
    }

    trends_payload = trends_response.json()
    assert trends_response.status_code == 200
    assert trends_payload["weeklyUsage"] == [
        {"day": "Tue", "hours": 1.0},
        {"day": "Wed", "hours": 0.5},
        {"day": "Thu", "hours": 1.5},
        {"day": "Fri", "hours": 0.8},
        {"day": "Sat", "hours": 0.5},
        {"day": "Sun", "hours": 0.8},
        {"day": "Mon", "hours": 1.0},
    ]
    assert trends_payload["weeklyTotalMinutes"] == 360
    assert trends_payload["topApps"] == [
        {"appId": "com.instagram.android", "appName": "Instagram", "minutes": 240},
        {"appId": "com.youtube.android", "appName": "YouTube", "minutes": 75},
        {"appId": "com.spotify.music", "appName": "Spotify", "minutes": 45},
    ]
    assert trends_payload["peakUsageWindow"] == "7 PM - 9 PM"
    assert len(trends_payload["hourlyUsage"]) == 24
    assert trends_payload["hourlyUsage"][19] == {"hour": "7pm", "minutes": 105}
    assert trends_payload["hourlyUsage"][20] == {"hour": "8pm", "minutes": 90}
    assert trends_payload["hourlyUsage"][21] == {"hour": "9pm", "minutes": 90}

    assert weekly_summary_response.status_code == 200
    assert weekly_summary_response.json() == {
        "screenTimeReductionPercent": 54,
        "totalWeekHours": 6.0,
        "dailyAverageHours": 0.9,
        "goalsMetDays": 7,
        "longestStreakDays": 11,
    }


def test_analytics_uses_exact_time_and_floors_only_display_minutes(
    client, monkeypatch
) -> None:
    monkeypatch.setattr(
        analytics_service_module,
        "current_utc_now",
        lambda: analytics_service_module.datetime(
            2026, 6, 8, 12, 10, tzinfo=analytics_service_module.timezone.utc
        ),
    )
    ingestion_response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                {
                    "sourceEventId": "messages-yesterday-299900",
                    "appId": "com.google.android.apps.messaging",
                    "appName": "Messages",
                    "category": "Social",
                    "startedAt": "2026-06-07T12:00:00.000Z",
                    "endedAt": "2026-06-07T12:04:59.900Z",
                    "timezone": "UTC",
                },
                {
                    "sourceEventId": "messages-today-315400",
                    "appId": "com.google.android.apps.messaging",
                    "appName": "Messages",
                    "category": "Social",
                    "startedAt": "2026-06-08T12:00:00.000Z",
                    "endedAt": "2026-06-08T12:05:15.400Z",
                    "timezone": "UTC",
                },
            ]
        },
    )

    assert ingestion_response.status_code == 200
    dashboard = client.get("/api/v1/analytics/dashboard").json()
    trends = client.get("/api/v1/analytics/trends").json()

    assert dashboard["todayTotalMinutes"] == 5
    assert dashboard["categoryBreakdown"] == [
        {
            "name": "Social & Messaging",
            "minutes": 5,
            "durationMilliseconds": 315_400,
            "apps": [
                {
                    "appId": "com.google.android.apps.messaging",
                    "appName": "Messages",
                    "minutes": 5,
                    "durationMilliseconds": 315_400,
                }
            ],
        }
    ]
    assert dashboard["deltaFromYesterdayPercent"] == 5
    assert dashboard["weeklyTotalMinutes"] == 10
    assert trends["weeklyTotalMinutes"] == 10
    assert trends["topApps"] == [
        {
            "appId": "com.google.android.apps.messaging",
            "appName": "Messages",
            "minutes": 10,
        }
    ]
    assert trends["hourlyUsage"][12] == {"hour": "12pm", "minutes": 10}


def test_authoritative_weekly_total_does_not_sum_rounded_daily_values(
    client, monkeypatch
) -> None:
    monkeypatch.setattr(
        analytics_service_module,
        "current_utc_now",
        lambda: analytics_service_module.datetime(
            2026, 6, 8, 12, 0, tzinfo=analytics_service_module.timezone.utc
        ),
    )
    events = []
    for day in range(2, 9):
        events.append(
            {
                "sourceEventId": f"four-minutes-{day}",
                "appId": "com.android.chrome",
                "appName": "com.android.chrome",
                "category": "Other",
                "startedAt": f"2026-06-{day:02d}T10:00:00Z",
                "endedAt": f"2026-06-{day:02d}T10:04:00Z",
                "timezone": "UTC",
            }
        )

    response = client.post("/api/v1/usage/events", json={"events": events})

    assert response.status_code == 200
    dashboard = client.get("/api/v1/analytics/dashboard").json()
    trends = client.get("/api/v1/analytics/trends").json()
    weekly_summary = client.get("/api/v1/analytics/weekly-summary").json()

    assert dashboard["weeklyUsageHours"] == [0.1] * 7
    assert dashboard["weeklyTotalMinutes"] == 28
    assert trends["weeklyUsage"] == [
        {"day": day, "hours": 0.1}
        for day in ["Tue", "Wed", "Thu", "Fri", "Sat", "Sun", "Mon"]
    ]
    assert trends["weeklyTotalMinutes"] == 28
    assert weekly_summary["totalWeekHours"] == 0.5


def test_known_packages_reclassify_exact_historical_style_category_duration(
    client, monkeypatch
) -> None:
    monkeypatch.setattr(
        analytics_service_module,
        "current_utc_now",
        lambda: analytics_service_module.datetime(
            2026, 6, 8, 12, 0, tzinfo=analytics_service_module.timezone.utc
        ),
    )
    response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                {
                    "sourceEventId": "play-store-sub-minute",
                    "appId": "com.android.vending",
                    "appName": "com.android.vending",
                    "category": "Productivity",
                    "startedAt": "2026-06-08T10:00:00.000Z",
                    "endedAt": "2026-06-08T10:00:18.738Z",
                    "timezone": "UTC",
                },
                {
                    "sourceEventId": "google-sub-minute",
                    "appId": "com.google.android.googlequicksearchbox",
                    "appName": "com.google.android.googlequicksearchbox",
                    "category": "Productivity",
                    "startedAt": "2026-06-08T10:01:00.000Z",
                    "endedAt": "2026-06-08T10:01:01.195Z",
                    "timezone": "UTC",
                },
            ]
        },
    )

    assert response.status_code == 200
    dashboard = client.get("/api/v1/analytics/dashboard").json()
    trends = client.get("/api/v1/analytics/trends").json()

    assert dashboard["todayTotalMinutes"] == 0
    assert dashboard["categoryBreakdown"] == [
        {
            "name": "System & Utilities",
            "minutes": 0,
            "durationMilliseconds": 18_738,
            "apps": [
                {
                    "appId": "com.android.vending",
                    "appName": "Google Play Store",
                    "minutes": 0,
                    "durationMilliseconds": 18_738,
                }
            ],
        },
        {
            "name": "Web & Search",
            "minutes": 0,
            "durationMilliseconds": 1_195,
            "apps": [
                {
                    "appId": "com.google.android.googlequicksearchbox",
                    "appName": "Google",
                    "minutes": 0,
                    "durationMilliseconds": 1_195,
                }
            ],
        },
    ]
    assert sum(
        item["durationMilliseconds"] for item in dashboard["categoryBreakdown"]
    ) == 19_933
    assert trends["topApps"] == [
        {
            "appId": "com.android.vending",
            "appName": "Google Play Store",
            "minutes": 0,
        },
        {
            "appId": "com.google.android.googlequicksearchbox",
            "appName": "Google",
            "minutes": 0,
        },
    ]
