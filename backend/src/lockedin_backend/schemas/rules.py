from __future__ import annotations

from pydantic import Field

from lockedin_backend.core.serialization import APIModel


class RuleResponse(APIModel):
    id: str
    app_id: str
    app_name: str
    limit_minutes: int
    enabled: bool


class RuleCreate(APIModel):
    app_id: str = Field(min_length=1)
    app_name: str = Field(min_length=1)
    limit_minutes: int = Field(gt=0)
    enabled: bool = True


class RuleUpdate(APIModel):
    app_name: str | None = Field(default=None, min_length=1)
    limit_minutes: int | None = Field(default=None, gt=0)
    enabled: bool | None = None
