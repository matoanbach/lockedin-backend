from urllib.parse import parse_qs

import httpx
import pytest

from lockedin_backend.core.settings import Settings
from lockedin_backend.services.keycloak_client import KeycloakClient, KeycloakRejected


SYNTHETIC_ACCESS_TOKEN = "synthetic-access-token-marker"


def _settings(*, backchannel: bool = False) -> Settings:
    return Settings(
        keycloak_issuer="https://issuer.test/realms/lockdin",
        keycloak_backchannel_base_url=(
            "http://keycloak:8080/" if backchannel else None
        ),
        keycloak_api_client_secret="synthetic-api-secret",
    )


def test_backchannel_urls_do_not_change_the_external_issuer_contract() -> None:
    settings = _settings(backchannel=True)

    assert settings.keycloak_issuer == "https://issuer.test/realms/lockdin"
    assert settings.keycloak_token_url == (
        "https://issuer.test/realms/lockdin/protocol/openid-connect/token"
    )
    assert settings.keycloak_backchannel_server_url == "http://keycloak:8080"
    assert settings.keycloak_backchannel_token_url == (
        "http://keycloak:8080/realms/lockdin/protocol/openid-connect/token"
    )


def test_revoke_access_token_identifies_as_public_mobile_client(monkeypatch) -> None:
    settings = _settings(backchannel=True)

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "POST"
        assert str(request.url) == settings.keycloak_backchannel_revocation_url
        assert parse_qs(request.content.decode("ascii")) == {
            "token": [SYNTHETIC_ACCESS_TOKEN],
            "token_type_hint": ["access_token"],
            "client_id": ["lockdin-mobile"],
        }
        assert "Authorization" not in request.headers
        return httpx.Response(200)

    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        KeycloakClient,
        "_client",
        lambda self: httpx.Client(transport=transport),
    )
    monkeypatch.setattr(
        KeycloakClient,
        "_secret",
        lambda self: pytest.fail("revocation must not read the API client secret"),
    )

    KeycloakClient(settings).revoke_access_token(SYNTHETIC_ACCESS_TOKEN)


def test_revoke_access_token_rejection_does_not_expose_token(
    monkeypatch, caplog
) -> None:
    settings = _settings()

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            400,
            json={
                "error": "invalid_request",
                "error_description": SYNTHETIC_ACCESS_TOKEN,
            },
        )

    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        KeycloakClient,
        "_client",
        lambda self: httpx.Client(transport=transport),
    )

    with pytest.raises(
        KeycloakRejected, match="Keycloak rejected token revocation"
    ) as caught:
        KeycloakClient(settings).revoke_access_token(SYNTHETIC_ACCESS_TOKEN)

    assert SYNTHETIC_ACCESS_TOKEN not in str(caught.value)
    assert SYNTHETIC_ACCESS_TOKEN not in repr(caught.value)
    assert SYNTHETIC_ACCESS_TOKEN not in caplog.text


def test_delete_user_uses_encoded_admin_path(monkeypatch) -> None:
    settings = _settings(backchannel=True)
    subject = "synthetic subject/with separator"

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "DELETE"
        assert str(request.url) == (
            "http://keycloak:8080/admin/realms/lockdin/users/"
            "synthetic%20subject%2Fwith%20separator"
        )
        assert "Authorization" in request.headers
        return httpx.Response(204)

    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        KeycloakClient,
        "_client",
        lambda self: httpx.Client(transport=transport),
    )
    monkeypatch.setattr(
        KeycloakClient,
        "_service_account_token",
        lambda self: "synthetic-service-token",
    )

    KeycloakClient(settings).delete_user(subject)
