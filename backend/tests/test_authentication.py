from __future__ import annotations

import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from lockedin_backend.api.dependencies.principal import get_current_principal
from lockedin_backend.app.main import create_app
from lockedin_backend.core.authentication import (
    AccessTokenClaims,
    InvalidAccessToken,
    validate_introspection,
)
from lockedin_backend.core.principal import CurrentPrincipal
from lockedin_backend.core.provider_events import (
    BACKCHANNEL_LOGOUT_EVENT,
    InvalidProviderEvent,
    provider_event_signature_payload,
    verify_backchannel_logout_token,
)
from lockedin_backend.core.settings import Settings
from lockedin_backend.models import (
    Account,
    ExternalIdentity,
    Preferences,
    Profile,
    RevokedProviderSession,
    SecurityAuditEvent,
)
from lockedin_backend.services.identity_service import IdentityService, PrincipalRejected
from lockedin_backend.services.keycloak_client import KeycloakUnavailable
from tests.conftest import TEST_ACCOUNT_ID, TEST_ISSUER, TEST_PROFILE_ID, TEST_SUBJECT


NOW = datetime(2026, 8, 8, 16, 0, tzinfo=timezone.utc)
EVENT_SECRET = "synthetic-event-secret-for-tests"


def _segment(value: dict) -> str:
    raw = json.dumps(value, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def access_token(*, algorithm: str = "RS256", marker: str = "signature") -> str:
    return f"{_segment({'alg': algorithm, 'typ': 'JWT'})}.{_segment({})}.{marker}"


def settings(**overrides) -> Settings:
    values = {
        "keycloak_issuer": TEST_ISSUER,
        "keycloak_api_client_secret": "synthetic-client-secret",
        "keycloak_event_webhook_secret": EVENT_SECRET,
    }
    values.update(overrides)
    return Settings(**values)


def introspection(**overrides) -> dict:
    values = {
        "active": True,
        "iss": TEST_ISSUER,
        "sub": "new-provider-subject",
        "sid": "new-provider-session",
        "iat": int(NOW.timestamp()),
        "exp": int((NOW + timedelta(minutes=5)).timestamp()),
        "aud": "lockdin-api",
        "azp": "lockdin-mobile",
        "email_verified": True,
        "scope": "openid profile email",
    }
    values.update(overrides)
    return values


class FakeKeycloakClient:
    def __init__(self, payload: dict | None = None) -> None:
        self.payload = payload or introspection(
            iat=int(datetime.now(timezone.utc).timestamp()),
            exp=int((datetime.now(timezone.utc) + timedelta(minutes=5)).timestamp()),
        )
        self.introspection_error: Exception | None = None
        self.revocation_error: Exception | None = None
        self.logout_error: Exception | None = None
        self.jwks: dict = {"keys": []}
        self.introspection_calls = 0
        self.revoked_tokens: list[str] = []
        self.logged_out_subjects: list[str] = []

    def introspect(self, token: str) -> dict:
        self.introspection_calls += 1
        if self.introspection_error:
            raise self.introspection_error
        return dict(self.payload)

    def revoke_access_token(self, token: str) -> None:
        self.revoked_tokens.append(token)
        if self.revocation_error:
            raise self.revocation_error

    def logout_user(self, subject: str) -> None:
        self.logged_out_subjects.append(subject)
        if self.logout_error:
            raise self.logout_error

    def fetch_jwks(self) -> dict:
        if self.introspection_error:
            raise self.introspection_error
        return self.jwks


def test_valid_introspection_contract() -> None:
    claims = validate_introspection(
        access_token(), introspection(), settings(), now=NOW
    )
    assert claims.subject == "new-provider-subject"
    assert claims.sid == "new-provider-session"


@pytest.mark.parametrize(
    ("change", "value"),
    [
        ("active", False),
        ("iss", "https://wrong.test/realms/lockdin"),
        ("aud", "wrong-api"),
        ("aud", ["lockdin-api", "extra-api"]),
        ("azp", "wrong-mobile"),
        ("email_verified", False),
        ("scope", "openid offline_access"),
        ("exp", int((NOW - timedelta(minutes=1)).timestamp())),
        ("iat", int((NOW + timedelta(minutes=1)).timestamp())),
        ("nbf", int((NOW + timedelta(minutes=1)).timestamp())),
    ],
)
def test_invalid_introspection_contract(change: str, value: object) -> None:
    with pytest.raises(InvalidAccessToken):
        validate_introspection(
            access_token(), introspection(**{change: value}), settings(), now=NOW
        )


@pytest.mark.parametrize("claim", ["sub", "sid", "iat", "exp"])
def test_required_claims(claim: str) -> None:
    payload = introspection()
    payload.pop(claim)
    with pytest.raises(InvalidAccessToken):
        validate_introspection(access_token(), payload, settings(), now=NOW)


@pytest.mark.parametrize("token", ["", "not-a-jwt", access_token(algorithm="HS256")])
def test_malformed_or_wrong_algorithm(token: str) -> None:
    with pytest.raises(InvalidAccessToken):
        validate_introspection(token, introspection(), settings(), now=NOW)


def test_missing_bearer_and_public_routes(session_factory) -> None:
    fake = FakeKeycloakClient()
    app = create_app(
        session_factory=session_factory, app_settings=settings(), keycloak_client=fake
    )
    with TestClient(app) as client:
        response = client.get("/api/v1/auth/session")
        assert response.status_code == 401
        assert response.json() == {"detail": "Authentication required"}
        assert response.headers["www-authenticate"] == "Bearer"
        assert client.get("/").status_code == 200
        assert client.get("/api/v1/health").status_code == 200
        config = client.get("/api/v1/auth/config")
        assert config.status_code == 200
        assert config.json() == {
            "issuer": TEST_ISSUER,
            "authorizationEndpoint": f"{TEST_ISSUER}/protocol/openid-connect/auth",
            "tokenEndpoint": f"{TEST_ISSUER}/protocol/openid-connect/token",
            "endSessionEndpoint": f"{TEST_ISSUER}/protocol/openid-connect/logout",
            "clientId": "lockdin-mobile",
            "redirectUri": "com.lockdin.lockdinapp:/oauth2redirect",
            "scopes": ["openid", "profile", "email"],
            "codeChallengeMethod": "S256",
        }
    assert fake.introspection_calls == 0


def test_provider_unavailable_fails_closed(session_factory) -> None:
    fake = FakeKeycloakClient()
    fake.introspection_error = KeycloakUnavailable("synthetic outage")
    app = create_app(
        session_factory=session_factory, app_settings=settings(), keycloak_client=fake
    )
    with TestClient(app) as client:
        response = client.get(
            "/api/v1/auth/session", headers={"Authorization": f"Bearer {access_token()}"}
        )
    assert response.status_code == 503
    assert response.json() == {"detail": "Authentication service unavailable"}


def test_first_login_provisions_once_and_each_request_introspects(session_factory) -> None:
    fake = FakeKeycloakClient()
    app = create_app(
        session_factory=session_factory, app_settings=settings(), keycloak_client=fake
    )
    headers = {"Authorization": f"Bearer {access_token()}"}
    with TestClient(app) as client:
        first = client.get("/api/v1/auth/session", headers=headers)
        second = client.get("/api/v1/auth/session", headers=headers)
    assert first.status_code == second.status_code == 200
    assert first.json()["accountId"] == second.json()["accountId"]
    assert fake.introspection_calls == 2
    with session_factory() as db:
        identity = db.scalar(
            select(ExternalIdentity).where(
                ExternalIdentity.issuer == TEST_ISSUER,
                ExternalIdentity.subject == "new-provider-subject",
            )
        )
        assert identity is not None
        assert identity.account.enabled is True
        assert identity.account.profile.is_demo is False
        assert identity.account.profile.is_active is True
        assert identity.account.profile.preferences is not None
        assert db.scalar(select(func.count()).select_from(ExternalIdentity)) == 2


def test_same_email_different_subjects_never_link(session_factory) -> None:
    service = IdentityService()
    issued = datetime.now(timezone.utc)
    with session_factory() as db:
        principals = [
            service.resolve_principal(
                db,
                AccessTokenClaims(
                    issuer=TEST_ISSUER,
                    subject=f"distinct-subject-{suffix}",
                    sid=f"distinct-sid-{suffix}",
                    issued_at=issued,
                    expires_at=issued + timedelta(minutes=5),
                ),
            )
            for suffix in ("a", "b")
        ]
    assert principals[0].account_id != principals[1].account_id


def test_provisioning_unique_conflict_recovers_existing_identity(
    session_factory, monkeypatch
) -> None:
    issued = datetime.now(timezone.utc)
    claims = AccessTokenClaims(
        issuer=TEST_ISSUER,
        subject=TEST_SUBJECT,
        sid="conflict-recovery-sid",
        issued_at=issued,
        expires_at=issued + timedelta(minutes=5),
    )
    with session_factory() as db:
        account = db.get(Account, TEST_ACCOUNT_ID)
        account.tokens_valid_after = issued - timedelta(seconds=1)
        identity = db.scalar(
            select(ExternalIdentity).where(
                ExternalIdentity.issuer == TEST_ISSUER,
                ExternalIdentity.subject == TEST_SUBJECT,
            )
        )

        class ConflictRepository:
            lookups = 0

            def get_external_identity(self, db, *, issuer, subject):
                self.lookups += 1
                return None if self.lookups == 1 else identity

            def get_revoked_session(self, db, *, issuer, sid):
                return None

        service = IdentityService(ConflictRepository())

        def conflict(*args, **kwargs):
            raise IntegrityError("synthetic unique conflict", {}, Exception())

        monkeypatch.setattr(service, "_create_identity", conflict)
        principal = service.resolve_principal(db, claims, now=issued)
    assert principal.account_id == TEST_ACCOUNT_ID


@pytest.mark.parametrize("state", ["disabled", "inactive", "demo", "boundary", "revoked"])
def test_local_account_and_session_rejections(session_factory, state: str) -> None:
    issued = datetime.now(timezone.utc)
    claims = AccessTokenClaims(
        issuer=TEST_ISSUER,
        subject=TEST_SUBJECT,
        sid="state-test-sid",
        issued_at=issued,
        expires_at=issued + timedelta(minutes=5),
    )
    with session_factory() as db:
        account = db.get(Account, TEST_ACCOUNT_ID)
        profile = db.get(Profile, TEST_PROFILE_ID)
        account.tokens_valid_after = issued - timedelta(seconds=1)
        if state == "disabled":
            account.enabled = False
        elif state == "inactive":
            profile.is_active = False
        elif state == "demo":
            profile.is_demo = True
        elif state == "boundary":
            account.tokens_valid_after = issued + timedelta(seconds=1)
        else:
            db.add(
                RevokedProviderSession(
                    account_id=account.id,
                    issuer=TEST_ISSUER,
                    sid=claims.sid,
                    revoked_at=issued,
                    expires_at=issued + timedelta(hours=1),
                )
            )
        db.commit()
        with pytest.raises(PrincipalRejected):
            IdentityService().resolve_principal(db, claims, now=issued)


def _overridden_app(session_factory, fake: FakeKeycloakClient, principal: CurrentPrincipal):
    app = create_app(
        session_factory=session_factory, app_settings=settings(), keycloak_client=fake
    )
    app.dependency_overrides[get_current_principal] = lambda: principal
    return app


def test_current_logout_is_local_even_when_provider_fails(
    session_factory, current_principal
) -> None:
    fake = FakeKeycloakClient()
    fake.revocation_error = KeycloakUnavailable("synthetic outage")
    app = _overridden_app(session_factory, fake, current_principal)
    raw_token = access_token(marker="sensitive-token-marker")
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/auth/logout", headers={"Authorization": f"Bearer {raw_token}"}
        )
    assert response.status_code == 204
    with session_factory() as db:
        revoked = db.scalar(
            select(RevokedProviderSession).where(
                RevokedProviderSession.sid == current_principal.sid
            )
        )
        audit = db.scalar(
            select(SecurityAuditEvent).where(
                SecurityAuditEvent.event_type == "session_logout"
            )
        )
        assert revoked is not None
        assert audit.outcome == "local_only_provider_failed"
        assert "sensitive-token-marker" not in repr(vars(audit))


def test_logout_all_advances_boundary_and_reconciles_provider(
    session_factory, current_principal
) -> None:
    fake = FakeKeycloakClient()
    app = _overridden_app(session_factory, fake, current_principal)
    with session_factory() as db:
        before = db.get(Account, current_principal.account_id).tokens_valid_after
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/auth/logout-all",
            headers={"Authorization": f"Bearer {access_token()}"},
        )
    assert response.status_code == 204
    assert fake.logged_out_subjects == [current_principal.subject]
    with session_factory() as db:
        account = db.get(Account, current_principal.account_id)
        audit = db.scalar(
            select(SecurityAuditEvent).where(
                SecurityAuditEvent.event_type == "account_logout_all"
            )
        )
        assert account.tokens_valid_after >= before
        assert audit.outcome == "success"


def test_logout_all_provider_failure_keeps_local_boundary(
    session_factory, current_principal
) -> None:
    fake = FakeKeycloakClient()
    fake.logout_error = KeycloakUnavailable("synthetic outage")
    app = _overridden_app(session_factory, fake, current_principal)
    with session_factory() as db:
        before = db.get(Account, current_principal.account_id).tokens_valid_after
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/auth/logout-all",
            headers={"Authorization": f"Bearer {access_token()}"},
        )
    assert response.status_code == 503
    with session_factory() as db:
        account = db.get(Account, current_principal.account_id)
        audit = db.scalar(
            select(SecurityAuditEvent).where(
                SecurityAuditEvent.event_type == "account_logout_all"
            )
        )
        assert account.tokens_valid_after >= before
        assert audit.outcome == "local_applied_provider_failed"


PRIVATE_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
PUBLIC_JWK = jwt.algorithms.RSAAlgorithm.to_jwk(PRIVATE_KEY.public_key(), as_dict=True)
PUBLIC_JWK.update({"kid": "synthetic-signing-key", "use": "sig", "alg": "RS256"})


def logout_token(**overrides) -> str:
    now = int(datetime.now(timezone.utc).timestamp())
    payload = {
        "iss": TEST_ISSUER,
        "aud": "lockdin-mobile",
        "iat": now,
        "jti": "logout-event-1",
        "events": {BACKCHANNEL_LOGOUT_EVENT: {}},
        "sub": TEST_SUBJECT,
        "sid": "backchannel-sid",
    }
    payload.update(overrides)
    payload = {key: value for key, value in payload.items() if value is not None}
    return jwt.encode(
        payload,
        PRIVATE_KEY,
        algorithm="RS256",
        headers={"kid": "synthetic-signing-key"},
    )


def test_signed_backchannel_logout_and_replay(session_factory) -> None:
    fake = FakeKeycloakClient()
    fake.jwks = {"keys": [PUBLIC_JWK]}
    app = create_app(
        session_factory=session_factory, app_settings=settings(), keycloak_client=fake
    )
    body = urlencode({"logout_token": logout_token()})
    with TestClient(app) as client:
        first = client.post(
            "/api/v1/auth/backchannel-logout",
            content=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        replay = client.post(
            "/api/v1/auth/backchannel-logout",
            content=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
    assert first.status_code == replay.status_code == 204
    with session_factory() as db:
        assert db.scalar(
            select(func.count()).select_from(SecurityAuditEvent).where(
                SecurityAuditEvent.provider_event_id == "logout-event-1"
            )
        ) == 1
        assert db.scalar(
            select(RevokedProviderSession).where(
                RevokedProviderSession.sid == "backchannel-sid"
            )
        ) is not None


def test_sid_only_backchannel_logout_is_globally_revoked(session_factory) -> None:
    fake = FakeKeycloakClient()
    fake.jwks = {"keys": [PUBLIC_JWK]}
    app = create_app(
        session_factory=session_factory, app_settings=settings(), keycloak_client=fake
    )
    token = logout_token(jti="sid-only-event", sub=None, sid="sid-only-session")
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/auth/backchannel-logout",
            content=urlencode({"logout_token": token}),
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
    assert response.status_code == 204
    with session_factory() as db:
        revoked = db.scalar(
            select(RevokedProviderSession).where(
                RevokedProviderSession.sid == "sid-only-session"
            )
        )
        assert revoked is not None and revoked.account_id is None


@pytest.mark.parametrize(
    "overrides",
    [
        {"iss": "https://wrong.test/realms/lockdin"},
        {"aud": "wrong-mobile"},
        {"aud": ["lockdin-mobile", "extra"]},
        {"iat": int((datetime.now(timezone.utc) - timedelta(hours=1)).timestamp())},
        {"nonce": "not-allowed"},
    ],
)
def test_invalid_backchannel_claims(overrides: dict) -> None:
    with pytest.raises(InvalidProviderEvent):
        verify_backchannel_logout_token(
            logout_token(**overrides), {"keys": [PUBLIC_JWK]}, settings()
        )


def test_backchannel_rejects_wrong_key_and_algorithm() -> None:
    other_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    wrong_key_token = jwt.encode(
        {
            "iss": TEST_ISSUER,
            "aud": "lockdin-mobile",
            "iat": int(datetime.now(timezone.utc).timestamp()),
            "jti": "wrong-key",
            "events": {BACKCHANNEL_LOGOUT_EVENT: {}},
            "sid": "wrong-key-sid",
        },
        other_key,
        algorithm="RS256",
        headers={"kid": "synthetic-signing-key"},
    )
    wrong_algorithm = jwt.encode(
        {
            "iss": TEST_ISSUER,
            "aud": "lockdin-mobile",
            "iat": int(datetime.now(timezone.utc).timestamp()),
            "jti": "wrong-algorithm",
            "events": {BACKCHANNEL_LOGOUT_EVENT: {}},
            "sid": "wrong-algorithm-sid",
        },
        "synthetic-hmac-key",
        algorithm="HS256",
        headers={"kid": "synthetic-signing-key"},
    )
    for token in (wrong_key_token, wrong_algorithm):
        with pytest.raises(InvalidProviderEvent):
            verify_backchannel_logout_token(token, {"keys": [PUBLIC_JWK]}, settings())


def _event_signature(payload: dict) -> str:
    digest = hmac.new(
        EVENT_SECRET.encode(),
        provider_event_signature_payload(
            event_id=payload["eventId"],
            occurred_at=payload["occurredAt"],
            issuer=payload["issuer"],
            subject=payload["subject"],
            action=payload["action"],
        ),
        hashlib.sha256,
    ).hexdigest()
    return f"v1={digest}"


def test_signed_provider_event_advances_boundary_and_is_idempotent(session_factory) -> None:
    fake = FakeKeycloakClient()
    app = create_app(
        session_factory=session_factory, app_settings=settings(), keycloak_client=fake
    )
    occurred_at = int(datetime.now(timezone.utc).timestamp())
    payload = {
        "eventId": "provider-event-1",
        "occurredAt": occurred_at,
        "issuer": TEST_ISSUER,
        "subject": TEST_SUBJECT,
        "action": "password_changed",
    }
    headers = {"X-LockdIn-Event-Signature": _event_signature(payload)}
    with TestClient(app) as client:
        first = client.post("/api/v1/auth/provider-events", json=payload, headers=headers)
        replay = client.post("/api/v1/auth/provider-events", json=payload, headers=headers)
    assert first.status_code == replay.status_code == 204
    assert fake.logged_out_subjects == [TEST_SUBJECT]
    with session_factory() as db:
        account = db.get(Account, TEST_ACCOUNT_ID)
        assert account.tokens_valid_after >= datetime.fromtimestamp(occurred_at)
        assert db.scalar(
            select(func.count()).select_from(SecurityAuditEvent).where(
                SecurityAuditEvent.provider_event_id == "provider-event-1"
            )
        ) == 1


def test_invalid_and_expired_provider_event_signatures(session_factory) -> None:
    fake = FakeKeycloakClient()
    app = create_app(
        session_factory=session_factory, app_settings=settings(), keycloak_client=fake
    )
    payload = {
        "eventId": "provider-event-invalid",
        "occurredAt": int((datetime.now(timezone.utc) - timedelta(minutes=5)).timestamp()),
        "issuer": TEST_ISSUER,
        "subject": TEST_SUBJECT,
        "action": "logout_all",
    }
    with TestClient(app) as client:
        wrong = client.post(
            "/api/v1/auth/provider-events",
            json=payload,
            headers={"X-LockdIn-Event-Signature": "v1=" + "0" * 64},
        )
        expired = client.post(
            "/api/v1/auth/provider-events",
            json=payload,
            headers={"X-LockdIn-Event-Signature": _event_signature(payload)},
        )
    assert wrong.status_code == expired.status_code == 400
    assert wrong.json() == expired.json() == {"detail": "Invalid provider event"}


def test_openapi_has_real_bearer_scheme_and_public_config(session_factory) -> None:
    app = create_app(
        session_factory=session_factory,
        app_settings=settings(),
        keycloak_client=FakeKeycloakClient(),
    )
    schema = app.openapi()
    assert schema["components"]["securitySchemes"]["KeycloakAccessToken"] == {
        "type": "http",
        "scheme": "bearer",
    }
    assert "security" not in schema["paths"]["/api/v1/auth/config"]["get"]
    assert schema["paths"]["/api/v1/auth/session"]["get"]["security"] == [
        {"KeycloakAccessToken": []}
    ]
