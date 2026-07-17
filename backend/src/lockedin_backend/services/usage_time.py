from __future__ import annotations

import math
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo


DEFAULT_CATEGORY = "Other"


def normalize_category(category: str | None) -> str:
    if category is None:
        return DEFAULT_CATEGORY

    stripped_category = category.strip()
    return stripped_category or DEFAULT_CATEGORY


def ensure_utc(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def derive_duration_minutes(started_at: datetime, ended_at: datetime) -> int:
    total_seconds = (ensure_utc(ended_at) - ensure_utc(started_at)).total_seconds()
    return max(1, math.ceil(total_seconds / 60))


def split_minutes_by_local_date(
    started_at: datetime, ended_at: datetime, timezone_name: str
) -> list[tuple[date, int]]:
    return _split_minutes_by_boundary(
        started_at,
        ended_at,
        timezone_name,
        key_fn=lambda current: current.date(),
        next_boundary_fn=lambda current, tz: datetime.combine(
            current.date() + timedelta(days=1),
            time.min,
            tzinfo=tz,
        ),
    )


def split_seconds_by_local_date(
    started_at: datetime, ended_at: datetime, timezone_name: str
) -> list[tuple[date, float]]:
    started_local = ensure_utc(started_at).astimezone(ZoneInfo(timezone_name))
    ended_local = ensure_utc(ended_at).astimezone(ZoneInfo(timezone_name))
    segments: list[tuple[date, float]] = []
    cursor = started_local
    while cursor < ended_local:
        boundary = datetime.combine(
            cursor.date() + timedelta(days=1),
            time.min,
            tzinfo=cursor.tzinfo,
        )
        segment_end = min(boundary, ended_local)
        seconds = (
            segment_end.astimezone(timezone.utc)
            - cursor.astimezone(timezone.utc)
        ).total_seconds()
        if seconds > 0:
            segments.append((cursor.date(), seconds))
        cursor = segment_end
    return segments


def split_minutes_by_local_hour(
    started_at: datetime, ended_at: datetime, timezone_name: str
) -> list[tuple[int, int]]:
    return _split_minutes_by_boundary(
        started_at,
        ended_at,
        timezone_name,
        key_fn=lambda current: current.hour,
        next_boundary_fn=lambda current, _tz: current.replace(
            minute=0,
            second=0,
            microsecond=0,
        )
        + timedelta(hours=1),
    )


def _split_minutes_by_boundary(
    started_at: datetime,
    ended_at: datetime,
    timezone_name: str,
    *,
    key_fn,
    next_boundary_fn,
) -> list[tuple[object, int]]:
    started_utc = ensure_utc(started_at)
    ended_utc = ensure_utc(ended_at)
    total_minutes = derive_duration_minutes(started_utc, ended_utc)
    timezone_value = ZoneInfo(timezone_name)
    started_local = started_utc.astimezone(timezone_value)
    ended_local = ended_utc.astimezone(timezone_value)

    segments: list[tuple[object, float]] = []
    cursor = started_local

    while cursor < ended_local:
        boundary = next_boundary_fn(cursor, timezone_value)
        segment_end = min(boundary, ended_local)
        segment_seconds = (segment_end - cursor).total_seconds()
        if segment_seconds > 0:
            segments.append((key_fn(cursor), segment_seconds))
        cursor = segment_end

    return _allocate_minutes(segments, total_minutes)


def _allocate_minutes(
    segments: list[tuple[object, float]], total_minutes: int
) -> list[tuple[object, int]]:
    if not segments:
        return []

    total_seconds = sum(segment_seconds for _, segment_seconds in segments)
    allocated_minutes: list[list[object | int]] = []
    remainders: list[tuple[float, int]] = []
    assigned_minutes = 0

    for index, (key, segment_seconds) in enumerate(segments):
        raw_minutes = (total_minutes * segment_seconds) / total_seconds
        base_minutes = math.floor(raw_minutes)
        allocated_minutes.append([key, base_minutes])
        remainders.append((raw_minutes - base_minutes, index))
        assigned_minutes += base_minutes

    for _, index in sorted(remainders, key=lambda item: (-item[0], item[1]))[
        : total_minutes - assigned_minutes
    ]:
        allocated_minutes[index][1] += 1

    return [
        (key, minutes)
        for key, minutes in allocated_minutes
        if isinstance(minutes, int) and minutes > 0
    ]
