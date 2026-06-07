import lockedin_backend.services.rule_status_service as rule_status_service_module


def test_rule_status_returns_empty_list_without_rules(client, monkeypatch) -> None:
    monkeypatch.setattr(
        rule_status_service_module,
        "current_utc_now",
        lambda: rule_status_service_module.datetime(
            2026, 6, 8, 12, 0, tzinfo=rule_status_service_module.timezone.utc
        ),
    )

    response = client.get("/api/v1/rules/status")

    assert response.status_code == 200
    assert response.json() == []


def test_rule_status_evaluates_enabled_and_disabled_rules(client, monkeypatch) -> None:
    monkeypatch.setattr(
        rule_status_service_module,
        "current_utc_now",
        lambda: rule_status_service_module.datetime(
            2026, 6, 8, 12, 0, tzinfo=rule_status_service_module.timezone.utc
        ),
    )

    under_limit_rule = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.spotify.music",
            "appName": "Spotify",
            "limitMinutes": 60,
            "enabled": True,
        },
    ).json()
    approaching_rule = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.youtube.android",
            "appName": "YouTube",
            "limitMinutes": 30,
            "enabled": True,
        },
    ).json()
    at_limit_rule = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.instagram.android",
            "appName": "Instagram",
            "limitMinutes": 45,
            "enabled": True,
        },
    ).json()
    over_limit_rule = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.zhiliaoapp.musically",
            "appName": "TikTok",
            "limitMinutes": 10,
            "enabled": True,
        },
    ).json()
    disabled_rule = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.google.android.apps.messaging",
            "appName": "Messages",
            "limitMinutes": 20,
            "enabled": False,
        },
    ).json()

    ingestion_response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                {
                    "sourceEventId": "spotify-usage",
                    "appId": "com.spotify.music",
                    "appName": "Spotify",
                    "category": "Entertainment",
                    "startedAt": "2026-06-08T12:00:00Z",
                    "endedAt": "2026-06-08T12:20:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "youtube-usage",
                    "appId": "com.youtube.android",
                    "appName": "YouTube",
                    "category": "Entertainment",
                    "startedAt": "2026-06-08T12:00:00Z",
                    "endedAt": "2026-06-08T12:24:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "instagram-usage",
                    "appId": "com.instagram.android",
                    "appName": "Instagram",
                    "category": "Social",
                    "startedAt": "2026-06-08T12:00:00Z",
                    "endedAt": "2026-06-08T12:45:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "tiktok-usage",
                    "appId": "com.zhiliaoapp.musically",
                    "appName": "TikTok",
                    "category": "Entertainment",
                    "startedAt": "2026-06-08T12:00:00Z",
                    "endedAt": "2026-06-08T12:14:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
                {
                    "sourceEventId": "messages-usage",
                    "appId": "com.google.android.apps.messaging",
                    "appName": "Messages",
                    "category": "Social",
                    "startedAt": "2026-06-08T12:00:00Z",
                    "endedAt": "2026-06-08T12:08:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                },
            ]
        },
    )

    assert ingestion_response.status_code == 200

    response = client.get("/api/v1/rules/status")

    assert response.status_code == 200
    assert response.json() == [
        {
            "ruleId": at_limit_rule["id"],
            "appId": "com.instagram.android",
            "appName": "Instagram",
            "usageDate": "2026-06-08",
            "enabled": True,
            "limitMinutes": 45,
            "usedMinutes": 45,
            "remainingMinutes": 0,
            "progressPercent": 100,
            "status": "at_limit",
            "isBlockedNow": False,
        },
        {
            "ruleId": disabled_rule["id"],
            "appId": "com.google.android.apps.messaging",
            "appName": "Messages",
            "usageDate": "2026-06-08",
            "enabled": False,
            "limitMinutes": 20,
            "usedMinutes": 8,
            "remainingMinutes": 12,
            "progressPercent": 40,
            "status": "disabled",
            "isBlockedNow": False,
        },
        {
            "ruleId": under_limit_rule["id"],
            "appId": "com.spotify.music",
            "appName": "Spotify",
            "usageDate": "2026-06-08",
            "enabled": True,
            "limitMinutes": 60,
            "usedMinutes": 20,
            "remainingMinutes": 40,
            "progressPercent": 33,
            "status": "under_limit",
            "isBlockedNow": False,
        },
        {
            "ruleId": over_limit_rule["id"],
            "appId": "com.zhiliaoapp.musically",
            "appName": "TikTok",
            "usageDate": "2026-06-08",
            "enabled": True,
            "limitMinutes": 10,
            "usedMinutes": 14,
            "remainingMinutes": 0,
            "progressPercent": 140,
            "status": "over_limit",
            "isBlockedNow": True,
        },
        {
            "ruleId": approaching_rule["id"],
            "appId": "com.google.android.youtube",
            "appName": "YouTube",
            "usageDate": "2026-06-08",
            "enabled": True,
            "limitMinutes": 30,
            "usedMinutes": 24,
            "remainingMinutes": 6,
            "progressPercent": 80,
            "status": "approaching_limit",
            "isBlockedNow": False,
        },
    ]


def test_rule_status_matches_legacy_youtube_rule_alias(client, monkeypatch) -> None:
    monkeypatch.setattr(
        rule_status_service_module,
        "current_utc_now",
        lambda: rule_status_service_module.datetime(
            2026, 6, 8, 12, 0, tzinfo=rule_status_service_module.timezone.utc
        ),
    )

    legacy_rule = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.youtube.android",
            "appName": "YouTube",
            "limitMinutes": 10,
            "enabled": True,
        },
    ).json()

    ingestion_response = client.post(
        "/api/v1/usage/events",
        json={
            "events": [
                {
                    "sourceEventId": "youtube-real-package",
                    "appId": "com.google.android.youtube",
                    "appName": "YouTube",
                    "category": "Entertainment",
                    "startedAt": "2026-06-08T12:00:00Z",
                    "endedAt": "2026-06-08T12:11:00Z",
                    "timezone": "Asia/Ho_Chi_Minh",
                }
            ]
        },
    )

    assert ingestion_response.status_code == 200

    response = client.get("/api/v1/rules/status")

    assert response.status_code == 200
    assert response.json() == [
        {
            "ruleId": legacy_rule["id"],
            "appId": "com.google.android.youtube",
            "appName": "YouTube",
            "usageDate": "2026-06-08",
            "enabled": True,
            "limitMinutes": 10,
            "usedMinutes": 11,
            "remainingMinutes": 0,
            "progressPercent": 110,
            "status": "over_limit",
            "isBlockedNow": True,
        }
    ]
