from __future__ import annotations

from pydantic import EmailStr, Field

from lockedin_backend.core.serialization import APIModel


class AccountabilityContactResponse(APIModel):
    id: str
    name: str
    email: EmailStr
    consent_confirmed: bool


class AccountabilityContactCreate(APIModel):
    email: EmailStr
    name: str | None = Field(default=None, min_length=1)
    consent_confirmed: bool = False
