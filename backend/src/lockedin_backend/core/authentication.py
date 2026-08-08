from __future__ import annotations

import base64
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from lockedin_backend.core.settings import Settings


class InvalidAccessToken(ValueError):
    """Raised for any credential that cannot establish a trusted principal."""


@dataclass(frozen=True, slots=True)
class AccessTokenClaims:
    issuer: str
    subject: str
    sid: str
    issued_at: datetime
    expires_at: datetime


def _integer_claim(payload: dict[str, Any], name: str) -> int:
    value = payload.get(name)
    if isinstance(value, bool) or not isinstance(value, int):
        raise InvalidAccessToken(f"Missing or invalid {name} claim")
    return value


def _required_string(payload: dict[str, Any], name: str, *, maximum: int = 255) -> str:
    value = payload.get(name)
    if not isinstance(value, str) or not value or len(value) > maximum:
        raise InvalidAccessToken(f"Missing or invalid {name} claim")
    return value


def _decode_header(access_token: str) -> dict[str, Any]:
    if not access_token or len(access_token) > 16_384:
        raise InvalidAccessToken("Malformed access token")
    parts = access_token.split(".")
    if len(parts) != 3:
        raise InvalidAccessToken("Malformed access token")
    try:
        encoded = parts[0] + "=" * (-len(parts[0]) % 4)
        header = json.loads(base64.urlsafe_b64decode(encoded).decode("utf-8"))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise InvalidAccessToken("Malformed access token") from exc
    if not isinstance(header, dict):
        raise InvalidAccessToken("Malformed access token")
    return header


def validate_introspection(
    access_token: str,
    payload: dict[str, Any],
    settings: Settings,
    *,
    now: datetime | None = None,
) -> AccessTokenClaims:
    """Validate the provider response and the restrictive LockdIn token contract."""

    header = _decode_header(access_token)
    if header.get("alg") != "RS256":
        raise InvalidAccessToken("Unsupported access-token algorithm")
    if payload.get("active") is not True:
        raise InvalidAccessToken("Inactive access token")

    issuer = _required_string(payload, "iss")
    subject = _required_string(payload, "sub")
    sid = _required_string(payload, "sid")
    if issuer != settings.keycloak_issuer:
        raise InvalidAccessToken("Unexpected issuer")
    if payload.get("azp") != settings.keycloak_mobile_client_id:
        raise InvalidAccessToken("Unexpected authorized party")
    if payload.get("email_verified") is not True:
        raise InvalidAccessToken("Email verification is required")

    audience = payload.get("aud")
    if isinstance(audience, str):
        audiences = {audience}
    elif isinstance(audience, list) and all(
        isinstance(item, str) and item for item in audience
    ):
        audiences = set(audience)
    else:
        raise InvalidAccessToken("Missing or invalid audience")
    if audiences != {settings.keycloak_api_client_id}:
        raise InvalidAccessToken("Unexpected audience")

    scopes = payload.get("scope", "")
    if not isinstance(scopes, str) or "offline_access" in scopes.split():
        raise InvalidAccessToken("Offline access is not permitted")

    issued_at = _integer_claim(payload, "iat")
    expires_at = _integer_claim(payload, "exp")
    not_before = payload.get("nbf")
    if not_before is not None:
        not_before = _integer_claim(payload, "nbf")

    current = now or datetime.now(timezone.utc)
    current_timestamp = int(current.timestamp())
    skew = settings.keycloak_clock_skew_seconds
    if issued_at > current_timestamp + skew:
        raise InvalidAccessToken("Access token was issued in the future")
    if expires_at <= current_timestamp - skew or expires_at <= issued_at:
        raise InvalidAccessToken("Access token is expired")
    if not_before is not None and not_before > current_timestamp + skew:
        raise InvalidAccessToken("Access token is not active yet")

    return AccessTokenClaims(
        issuer=issuer,
        subject=subject,
        sid=sid,
        issued_at=datetime.fromtimestamp(issued_at, timezone.utc),
        expires_at=datetime.fromtimestamp(expires_at, timezone.utc),
    )
