from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import Any

from pydantic import Field

from lockedin_backend.core.serialization import APIModel


class EnforcementEventType(StrEnum):
    WARNING_APPROACHING_LIMIT = "warning_approaching_limit"
    WARNING_LIMIT_REACHED = "warning_limit_reached"
    INTERVENTION_BLOCKED = "intervention_blocked"


class EnforcementEventCreate(APIModel):
    rule_id: str | None = None
    app_id: str = Field(min_length=1)
    event_type: EnforcementEventType
    usage_date: date
    used_minutes: int = Field(ge=0)
    limit_minutes: int = Field(gt=0)
    metadata: dict[str, Any] | None = None


class EnforcementEventResponse(APIModel):
    id: str
    rule_id: str | None
    app_id: str
    event_type: EnforcementEventType
    usage_date: date
    used_minutes: int
    limit_minutes: int
    created_at: datetime
