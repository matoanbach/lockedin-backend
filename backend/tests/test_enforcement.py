from lockedin_backend.models import EnforcementEvent


def test_create_enforcement_event_persists_record(client, db_session) -> None:
    rule_response = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.youtube.android",
            "appName": "YouTube",
            "limitMinutes": 10,
            "enabled": True,
        },
    )
    rule_id = rule_response.json()["id"]

    response = client.post(
        "/api/v1/enforcement/events",
        json={
            "ruleId": rule_id,
            "appId": "com.youtube.android",
            "eventType": "warning_approaching_limit",
            "usageDate": "2026-06-08",
            "usedMinutes": 8,
            "limitMinutes": 10,
            "metadata": {"source": "app_resume"},
        },
    )

    assert response.status_code == 201
    assert response.json()["ruleId"] == rule_id
    assert response.json()["eventType"] == "warning_approaching_limit"

    stored_event = db_session.query(EnforcementEvent).one()
    assert stored_event.app_id == "com.youtube.android"
    assert stored_event.event_type == "warning_approaching_limit"


def test_create_enforcement_event_for_missing_rule_returns_not_found(client) -> None:
    response = client.post(
        "/api/v1/enforcement/events",
        json={
            "ruleId": "missing-rule",
            "appId": "com.youtube.android",
            "eventType": "warning_limit_reached",
            "usageDate": "2026-06-08",
            "usedMinutes": 10,
            "limitMinutes": 10,
        },
    )

    assert response.status_code == 404


def test_create_intervention_dismissed_event_persists_record(client, db_session) -> None:
    rule_response = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.google.android.youtube",
            "appName": "YouTube",
            "limitMinutes": 10,
            "enabled": True,
        },
    )
    rule_id = rule_response.json()["id"]

    response = client.post(
        "/api/v1/enforcement/events",
        json={
            "ruleId": rule_id,
            "appId": "com.google.android.youtube",
            "eventType": "intervention_dismissed",
            "usageDate": "2026-06-08",
            "usedMinutes": 14,
            "limitMinutes": 10,
            "metadata": {"source": "android_accessibility", "action": "stay_in_lockdin"},
        },
    )

    assert response.status_code == 201
    assert response.json()["eventType"] == "intervention_dismissed"

    stored_event = db_session.query(EnforcementEvent).order_by(EnforcementEvent.created_at.desc()).first()
    assert stored_event is not None
    assert stored_event.event_type == "intervention_dismissed"
