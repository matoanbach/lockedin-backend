from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from lockedin_backend.api.dependencies.principal import (
    get_current_principal,
    get_operator_principal,
)
from lockedin_backend.core.principal import CurrentPrincipal, OperatorPrincipal
from lockedin_backend.models import (
    Account,
    ExternalIdentity,
    Preferences,
    Profile,
    UsageDailyAppAggregate,
)


def _usage_payload(source_event_id: str, started_at: datetime) -> dict:
    return {
        "events": [
            {
                "sourceEventId": source_event_id,
                "appId": "com.example.focus",
                "appName": "Focus",
                "category": "Productivity",
                "startedAt": started_at.isoformat(),
                "endedAt": (started_at + timedelta(minutes=20)).isoformat(),
                "timezone": "UTC",
            }
        ]
    }


def _add_account_b(db_session) -> CurrentPrincipal:
    account_id = "20000000-0000-0000-0000-000000000001"
    profile_id = "20000000-0000-0000-0000-000000000002"
    issuer = "https://issuer.test/realms/lockdin"
    subject = "synthetic-account-b"
    db_session.add(
        Profile(
            id=profile_id,
            slug="synthetic-account-b",
            name="Synthetic Account B",
            is_demo=False,
            is_active=True,
        )
    )
    db_session.add(Account(id=account_id, profile_id=profile_id, enabled=True))
    db_session.add(
        ExternalIdentity(account_id=account_id, issuer=issuer, subject=subject)
    )
    db_session.add(Preferences(profile_id=profile_id))
    db_session.commit()
    return CurrentPrincipal(
        account_id=account_id,
        profile_id=profile_id,
        issuer=issuer,
        subject=subject,
        sid="synthetic-session-b",
    )


def _select_principal(client: TestClient, principal: CurrentPrincipal) -> None:
    client.app.dependency_overrides[get_current_principal] = lambda: principal


def test_all_user_routes_fail_closed_before_phase_c(unauthenticated_client) -> None:
    valid_rule = {
        "appId": "com.example.app",
        "appName": "Example",
        "limitMinutes": 30,
    }
    valid_contact = {"email": "synthetic@example.com", "consentConfirmed": True}
    now = datetime.now(timezone.utc) - timedelta(hours=1)
    valid_enforcement = {
        "appId": "com.example.app",
        "eventType": "warning_approaching_limit",
        "usageDate": now.date().isoformat(),
        "usedMinutes": 20,
        "limitMinutes": 30,
    }
    requests = [
        ("get", "/api/v1/rules", None),
        ("get", "/api/v1/rules/status", None),
        ("post", "/api/v1/rules", valid_rule),
        ("patch", "/api/v1/rules/missing", {"limitMinutes": 20}),
        ("delete", "/api/v1/rules/missing", None),
        ("post", "/api/v1/usage/events", _usage_payload("unauth", now)),
        ("get", "/api/v1/analytics/dashboard", None),
        ("get", "/api/v1/analytics/trends", None),
        ("get", "/api/v1/analytics/weekly-summary", None),
        ("post", "/api/v1/enforcement/events", valid_enforcement),
        ("get", "/api/v1/accountability/contacts", None),
        ("post", "/api/v1/accountability/contacts", valid_contact),
        ("delete", "/api/v1/accountability/contacts/missing", None),
        ("get", "/api/v1/me/preferences", None),
        ("put", "/api/v1/me/preferences", {"defaultDailyLimitMinutes": 60}),
    ]

    for method, path, payload in requests:
        request = getattr(unauthenticated_client, method)
        response = request(path) if payload is None else request(path, json=payload)
        assert response.status_code == 401, (method, path, response.text)
        assert response.json() == {"detail": "Authentication required"}
        assert response.headers["www-authenticate"] == "Bearer"

    assert unauthenticated_client.get("/api/v1/health").status_code == 200
    assert unauthenticated_client.get("/").status_code == 200
    assert (
        unauthenticated_client.post("/api/v1/usage/aggregates/rebuild").status_code
        == 403
    )


def test_two_accounts_are_isolated_across_user_routes(
    client, db_session, current_principal
) -> None:
    principal_b = _add_account_b(db_session)
    now = datetime.now(timezone.utc) - timedelta(hours=2)

    rule_a = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.example.focus",
            "appName": "Focus A",
            "limitMinutes": 45,
        },
    ).json()
    contact_a = client.post(
        "/api/v1/accountability/contacts",
        json={"email": "account-a@example.com", "consentConfirmed": True},
    ).json()
    assert client.put(
        "/api/v1/me/preferences", json={"defaultDailyLimitMinutes": 45}
    ).status_code == 200
    assert client.post(
        "/api/v1/usage/events", json=_usage_payload("shared-source", now)
    ).status_code == 200

    dashboard_a = client.get("/api/v1/analytics/dashboard").json()
    _select_principal(client, principal_b)

    assert client.get("/api/v1/rules").json() == []
    assert client.get("/api/v1/rules/status").json() == []
    assert client.get("/api/v1/accountability/contacts").json() == []
    assert client.get("/api/v1/me/preferences").json()[
        "defaultDailyLimitMinutes"
    ] == 180
    assert client.get("/api/v1/analytics/dashboard").json()[
        "todayTotalMinutes"
    ] == 0

    missing_rule = client.patch(
        "/api/v1/rules/does-not-exist", json={"limitMinutes": 10}
    )
    cross_rule = client.patch(
        f"/api/v1/rules/{rule_a['id']}", json={"limitMinutes": 10}
    )
    assert (cross_rule.status_code, cross_rule.json()) == (
        missing_rule.status_code,
        missing_rule.json().copy() | {
            "detail": f"Rule '{rule_a['id']}' was not found"
        },
    )
    assert cross_rule.status_code == 404
    assert client.delete(f"/api/v1/rules/{rule_a['id']}").status_code == 404
    assert client.delete(
        f"/api/v1/accountability/contacts/{contact_a['id']}"
    ).status_code == 404

    cross_enforcement = client.post(
        "/api/v1/enforcement/events",
        json={
            "ruleId": rule_a["id"],
            "appId": "com.example.focus",
            "eventType": "warning_limit_reached",
            "usageDate": now.date().isoformat(),
            "usedMinutes": 45,
            "limitMinutes": 45,
        },
    )
    missing_enforcement = client.post(
        "/api/v1/enforcement/events",
        json={
            "ruleId": "does-not-exist",
            "appId": "com.example.focus",
            "eventType": "warning_limit_reached",
            "usageDate": now.date().isoformat(),
            "usedMinutes": 45,
            "limitMinutes": 45,
        },
    )
    assert cross_enforcement.status_code == missing_enforcement.status_code == 404

    first_b = client.post(
        "/api/v1/usage/events", json=_usage_payload("shared-source", now)
    )
    duplicate_b = client.post(
        "/api/v1/usage/events", json=_usage_payload("shared-source", now)
    )
    overlap_b = client.post(
        "/api/v1/usage/events", json=_usage_payload("overlap-b", now)
    )
    assert first_b.json()["createdCount"] == 1
    assert duplicate_b.json()["duplicateCount"] == 1
    assert overlap_b.status_code == 409

    rule_b = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.example.focus",
            "appName": "Focus B",
            "limitMinutes": 20,
        },
    )
    assert rule_b.status_code == 201
    assert len(client.get("/api/v1/rules/status").json()) == 1

    _select_principal(client, current_principal)
    assert len(client.get("/api/v1/rules").json()) == 1
    assert len(client.get("/api/v1/accountability/contacts").json()) == 1
    assert client.get("/api/v1/analytics/dashboard").json() == dashboard_a


def test_aggregate_rebuild_requires_operator_scope_and_stays_profile_scoped(
    client, db_session, current_principal
) -> None:
    principal_b = _add_account_b(db_session)
    now = datetime.now(timezone.utc).replace(
        hour=12, minute=0, second=0, microsecond=0
    ) - timedelta(days=1)
    assert client.post(
        "/api/v1/usage/events", json=_usage_payload("aggregate-a", now)
    ).status_code == 200
    _select_principal(client, principal_b)
    assert client.post(
        "/api/v1/usage/events",
        json=_usage_payload("aggregate-b", now - timedelta(hours=1)),
    ).status_code == 200

    assert client.post("/api/v1/usage/aggregates/rebuild").status_code == 403
    aggregate_a = db_session.query(UsageDailyAppAggregate).filter_by(
        profile_id=current_principal.profile_id
    ).one()
    aggregate_a.total_minutes = 777
    db_session.commit()

    client.app.dependency_overrides[get_operator_principal] = lambda: OperatorPrincipal(
        operator_id="synthetic-operator",
        profile_id=principal_b.profile_id,
    )
    response = client.post("/api/v1/usage/aggregates/rebuild")
    db_session.expire_all()

    assert response.status_code == 200
    assert db_session.query(UsageDailyAppAggregate).filter_by(
        profile_id=current_principal.profile_id
    ).one().total_minutes == 777
    aggregate_b_rows = db_session.query(UsageDailyAppAggregate).filter_by(
        profile_id=principal_b.profile_id
    ).all()
    assert sum(row.total_minutes for row in aggregate_b_rows) == 20
