from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, field_validator, model_validator

from lockedin_backend.core.serialization import APIModel


class UsageEventCreate(APIModel):
    source_event_id: str = Field(min_length=1, max_length=255)
    app_id: str = Field(min_length=1, max_length=255)
    app_name: str = Field(min_length=1, max_length=255)
    category: str | None = Field(default=None, max_length=100)
    started_at: datetime
    ended_at: datetime
    timezone: str = Field(min_length=1, max_length=100)

    @field_validator("source_event_id", "app_id", "app_name", "timezone")
    @classmethod
    def strip_required_strings(cls, value: str) -> str:
        stripped_value = value.strip()
        if not stripped_value:
            raise ValueError("Value must not be blank")
        return stripped_value

    @field_validator("category")
    @classmethod
    def strip_optional_category(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped_value = value.strip()
        return stripped_value or None

    @field_validator("started_at", "ended_at")
    @classmethod
    def require_timezone_aware_datetime(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("Datetime must include timezone information")
        return value

    @field_validator("timezone")
    @classmethod
    def validate_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("Timezone must be a valid IANA timezone") from exc
        return value

    @model_validator(mode="after")
    def validate_time_range(self) -> UsageEventCreate:
        if self.ended_at <= self.started_at:
            raise ValueError("endedAt must be after startedAt")
        return self


class UsageIngestionRequest(APIModel):
    events: list[UsageEventCreate] = Field(min_length=1)


class UsageIngestionResponse(APIModel):
    received_count: int
    created_count: int
    duplicate_count: int
