import pytest
from pydantic import ValidationError

from lockedin_backend.core.settings import Settings


def test_backchannel_base_url_normalizes_and_allows_internal_http() -> None:
    settings = Settings(
        keycloak_issuer="https://node.example.ts.net/realms/lockdin/",
        keycloak_backchannel_base_url="http://keycloak:8080/",
    )

    assert settings.keycloak_issuer == "https://node.example.ts.net/realms/lockdin"
    assert settings.keycloak_backchannel_base_url == "http://keycloak:8080"
    assert settings.keycloak_backchannel_jwks_url == (
        "http://keycloak:8080/realms/lockdin/protocol/openid-connect/certs"
    )


@pytest.mark.parametrize(
    "value",
    [
        "ftp://keycloak:8080",
        "http://user:password@keycloak:8080",
        "http://keycloak:8080?target=other",
        "http://keycloak:8080#fragment",
        "http://keycloak:not-a-port",
    ],
)
def test_backchannel_base_url_rejects_unsafe_or_invalid_values(value: str) -> None:
    with pytest.raises(ValidationError):
        Settings(keycloak_backchannel_base_url=value)
