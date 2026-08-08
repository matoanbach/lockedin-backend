from __future__ import annotations

import hashlib
import hmac
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import jwt

from lockedin_backend.core.settings import Settings


BACKCHANNEL_LOGOUT_EVENT = "http://schemas.openid.net/event/backchannel-logout"


class InvalidProviderEvent(ValueError):
    """Raised when an identity-provider callback cannot be authenticated."""


@dataclass(frozen=True, slots=True)
class BackchannelLogoutClaims:
    issuer: str
    subject: str | None
    sid: str | None
    event_id: str
    occurred_at: datetime


def verify_backchannel_logout_token(
    logout_token: str,
    jwks: dict[str, Any],
    settings: Settings,
    *,
    now: datetime | None = None,
) -> BackchannelLogoutClaims:
    if not logout_token or len(logout_token) > 16_384:
        raise InvalidProviderEvent("Invalid logout token")
    try:
        header = jwt.get_unverified_header(logout_token)
    except jwt.PyJWTError as exc:
        raise InvalidProviderEvent("Invalid logout token") from exc
    if header.get("alg") != "RS256" or not isinstance(header.get("kid"), str):
        raise InvalidProviderEvent("Invalid logout token")

    matching = [
        key
        for key in jwks.get("keys", [])
        if isinstance(key, dict)
        and key.get("kid") == header["kid"]
        and key.get("kty") == "RSA"
    ]
    if len(matching) != 1:
        raise InvalidProviderEvent("Invalid logout token")
    try:
        signing_key = jwt.PyJWK.from_dict(matching[0]).key
        payload = jwt.decode(
            logout_token,
            signing_key,
            algorithms=["RS256"],
            audience=settings.keycloak_mobile_client_id,
            issuer=settings.keycloak_issuer,
            leeway=settings.keycloak_clock_skew_seconds,
            options={"require": ["iss", "aud", "iat", "jti", "events"]},
        )
    except (jwt.PyJWTError, ValueError) as exc:
        raise InvalidProviderEvent("Invalid logout token") from exc

    if "nonce" in payload:
        raise InvalidProviderEvent("Invalid logout token")
    audience = payload.get("aud")
    audiences = {audience} if isinstance(audience, str) else set(audience or [])
    if audiences != {settings.keycloak_mobile_client_id}:
        raise InvalidProviderEvent("Invalid logout token")
    events = payload.get("events")
    if (
        not isinstance(events, dict)
        or not isinstance(events.get(BACKCHANNEL_LOGOUT_EVENT), dict)
    ):
        raise InvalidProviderEvent("Invalid logout token")
    event_id = payload.get("jti")
    subject = payload.get("sub")
    sid = payload.get("sid")
    if not isinstance(event_id, str) or not event_id or len(event_id) > 255:
        raise InvalidProviderEvent("Invalid logout token")
    if subject is not None and (
        not isinstance(subject, str) or not subject or len(subject) > 255
    ):
        raise InvalidProviderEvent("Invalid logout token")
    if sid is not None and (not isinstance(sid, str) or not sid or len(sid) > 255):
        raise InvalidProviderEvent("Invalid logout token")
    if subject is None and sid is None:
        raise InvalidProviderEvent("Invalid logout token")

    issued_at = payload.get("iat")
    if isinstance(issued_at, bool) or not isinstance(issued_at, int):
        raise InvalidProviderEvent("Invalid logout token")
    current = now or datetime.now(timezone.utc)
    if abs(int(current.timestamp()) - issued_at) > (
        settings.keycloak_backchannel_max_age_seconds
        + settings.keycloak_clock_skew_seconds
    ):
        raise InvalidProviderEvent("Expired logout token")

    return BackchannelLogoutClaims(
        issuer=settings.keycloak_issuer,
        subject=subject,
        sid=sid,
        event_id=event_id,
        occurred_at=datetime.fromtimestamp(issued_at, timezone.utc),
    )


def provider_event_signature_payload(
    *, event_id: str, occurred_at: int, issuer: str, subject: str, action: str
) -> bytes:
    return f"{event_id}\n{occurred_at}\n{issuer}\n{subject}\n{action}".encode("utf-8")


def verify_provider_event_signature(
    *,
    event_id: str,
    occurred_at: int,
    issuer: str,
    subject: str,
    action: str,
    signature: str,
    secret: str,
    max_age_seconds: int,
    now: datetime | None = None,
) -> None:
    current = now or datetime.now(timezone.utc)
    if abs(int(current.timestamp()) - occurred_at) > max_age_seconds:
        raise InvalidProviderEvent("Provider event timestamp is outside the window")
    expected = hmac.new(
        secret.encode("utf-8"),
        provider_event_signature_payload(
            event_id=event_id,
            occurred_at=occurred_at,
            issuer=issuer,
            subject=subject,
            action=action,
        ),
        hashlib.sha256,
    ).hexdigest()
    if not signature.startswith("v1=") or not hmac.compare_digest(
        signature[3:], expected
    ):
        raise InvalidProviderEvent("Invalid provider event signature")
