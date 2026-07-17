from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, field_validator, model_validator

from lockedin_backend.core.serialization import APIModel


MAX_USAGE_EVENTS_PER_REQUEST = 100
MAX_USAGE_EVENT_DURATION = timedelta(hours=6)
MAX_USAGE_EVENT_AGE = timedelta(days=90)
MAX_USAGE_EVENT_FUTURE_TOLERANCE = timedelta(minutes=5)
MAX_USAGE_PAYLOAD_BYTES = 128 * 1024


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
        if self.ended_at - self.started_at > MAX_USAGE_EVENT_DURATION:
            raise ValueError("Usage events may not be longer than 6 hours")

        now = datetime.now(timezone.utc)
        started_at_utc = self.started_at.astimezone(timezone.utc)
        ended_at_utc = self.ended_at.astimezone(timezone.utc)
        if started_at_utc < now - MAX_USAGE_EVENT_AGE:
            raise ValueError("Usage events may not be older than 90 days")
        if started_at_utc > now + MAX_USAGE_EVENT_FUTURE_TOLERANCE:
            raise ValueError("startedAt is too far in the future")
        if ended_at_utc > now + MAX_USAGE_EVENT_FUTURE_TOLERANCE:
            raise ValueError("endedAt is too far in the future")
        return self


class UsageIngestionRequest(APIModel):
    events: list[UsageEventCreate] = Field(
        min_length=1,
        max_length=MAX_USAGE_EVENTS_PER_REQUEST,
    )

    @model_validator(mode="after")
    def validate_payload_size_and_overlaps(self) -> UsageIngestionRequest:
        payload_size = len(self.model_dump_json(by_alias=True).encode("utf-8"))
        if payload_size > MAX_USAGE_PAYLOAD_BYTES:
            raise ValueError("Usage ingestion payload may not exceed 128 KiB")

        events_by_app: dict[str, list[UsageEventCreate]] = {}
        for event in self.events:
            events_by_app.setdefault(event.app_id, []).append(event)

        for app_events in events_by_app.values():
            sorted_events = sorted(app_events, key=lambda item: item.started_at)
            for previous, current in zip(sorted_events, sorted_events[1:]):
                if current.source_event_id == previous.source_event_id:
                    continue
                if current.started_at < previous.ended_at:
                    raise ValueError(
                        "Usage events for the same app may not overlap"
                    )
        return self


class UsageIngestionResponse(APIModel):
    received_count: int
    created_count: int
    duplicate_count: int


class UsageAggregateRebuildResponse(APIModel):
    event_count: int
    app_aggregate_count: int
    category_aggregate_count: int
