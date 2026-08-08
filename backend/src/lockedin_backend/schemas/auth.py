from typing import Literal

from pydantic import Field

from lockedin_backend.core.serialization import APIModel


class AuthConfigResponse(APIModel):
    issuer: str
    authorization_endpoint: str
    token_endpoint: str
    end_session_endpoint: str
    client_id: str
    redirect_uri: str
    scopes: list[str]
    code_challenge_method: Literal["S256"] = "S256"


class SessionResponse(APIModel):
    account_id: str
    profile_id: str
    issuer: str
    subject: str
    sid: str


class ProviderSecurityEventRequest(APIModel):
    event_id: str = Field(min_length=1, max_length=255)
    occurred_at: int = Field(gt=0)
    issuer: str = Field(min_length=1, max_length=255)
    subject: str = Field(min_length=1, max_length=255)
    action: Literal["password_changed", "logout_all", "account_disabled"]
