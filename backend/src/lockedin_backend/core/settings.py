from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic import SecretStr
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parents[3]
DEFAULT_DATABASE_URL = "postgresql+psycopg://postgres:postgres@localhost:5433/lockedin"
DEFAULT_KEYCLOAK_ISSUER = "https://192.168.2.44/realms/lockdin"
DEFAULT_KEYCLOAK_REDIRECT_URI = "com.lockdin.lockdinapp:/oauth2redirect"


class Settings(BaseSettings):
    app_name: str = Field(default="LockdIn Backend")
    app_version: str = Field(default="0.1.0")
    debug: bool = Field(default=True)
    database_url: str = Field(default=DEFAULT_DATABASE_URL)
    cors_allowed_origin_regex: str = Field(
        default=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    )
    keycloak_issuer: str = Field(default=DEFAULT_KEYCLOAK_ISSUER)
    keycloak_mobile_client_id: str = Field(default="lockdin-mobile")
    keycloak_api_client_id: str = Field(default="lockdin-api")
    keycloak_api_client_secret: SecretStr | None = Field(default=None)
    keycloak_redirect_uri: str = Field(default=DEFAULT_KEYCLOAK_REDIRECT_URI)
    keycloak_ca_bundle: Path | None = Field(default=None)
    keycloak_request_timeout_seconds: float = Field(default=3.0, gt=0, le=30)
    keycloak_max_concurrent_requests: int = Field(default=20, ge=1, le=200)
    keycloak_clock_skew_seconds: int = Field(default=30, ge=0, le=300)
    keycloak_session_max_seconds: int = Field(default=8 * 60 * 60, ge=300)
    keycloak_backchannel_max_age_seconds: int = Field(default=5 * 60, ge=30)
    keycloak_event_webhook_secret: SecretStr | None = Field(default=None)
    keycloak_event_max_age_seconds: int = Field(default=60, ge=10, le=300)

    @field_validator("debug", mode="before")
    @classmethod
    def parse_debug(cls, value: object) -> object:
        if isinstance(value, str) and value.lower() in {"release", "prod", "production"}:
            return False
        return value

    @field_validator("keycloak_issuer")
    @classmethod
    def normalize_keycloak_issuer(cls, value: str) -> str:
        issuer = value.rstrip("/")
        if not issuer.startswith("https://") or "/realms/" not in issuer:
            raise ValueError("KEYCLOAK_ISSUER must be an HTTPS Keycloak realm issuer")
        return issuer

    @property
    def keycloak_realm(self) -> str:
        return self.keycloak_issuer.rsplit("/realms/", 1)[1]

    @property
    def keycloak_server_url(self) -> str:
        return self.keycloak_issuer.rsplit("/realms/", 1)[0]

    @property
    def keycloak_introspection_url(self) -> str:
        return f"{self.keycloak_issuer}/protocol/openid-connect/token/introspect"

    @property
    def keycloak_token_url(self) -> str:
        return f"{self.keycloak_issuer}/protocol/openid-connect/token"

    @property
    def keycloak_authorization_url(self) -> str:
        return f"{self.keycloak_issuer}/protocol/openid-connect/auth"

    @property
    def keycloak_end_session_url(self) -> str:
        return f"{self.keycloak_issuer}/protocol/openid-connect/logout"

    @property
    def keycloak_revocation_url(self) -> str:
        return f"{self.keycloak_issuer}/protocol/openid-connect/revoke"

    @property
    def keycloak_jwks_url(self) -> str:
        return f"{self.keycloak_issuer}/protocol/openid-connect/certs"

    model_config = SettingsConfigDict(
        env_file=BASE_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
