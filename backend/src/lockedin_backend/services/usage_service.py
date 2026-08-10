from collections import defaultdict
from collections.abc import Iterable
from datetime import datetime, timezone
from hashlib import sha256

from sqlalchemy.orm import Session

from lockedin_backend.models import UsageEvent
from lockedin_backend.repositories.usage_daily_app_aggregate_repository import (
    UsageDailyAppAggregateRepository,
)
from lockedin_backend.repositories.usage_daily_category_aggregate_repository import (
    UsageDailyCategoryAggregateRepository,
)
from lockedin_backend.repositories.usage_repository import UsageRepository
from lockedin_backend.schemas.usage import (
    UsageAggregateRebuildResponse,
    UsageEventCreate,
    UsageIngestionRequest,
    UsageIngestionResponse,
)
from lockedin_backend.services.usage_time import (
    completed_minutes,
    derive_duration_minutes,
    normalize_category,
    split_milliseconds_by_local_date,
)


class UsageService:
    def __init__(self) -> None:
        self.usage_repository = UsageRepository()
        self.app_aggregate_repository = UsageDailyAppAggregateRepository()
        self.category_aggregate_repository = UsageDailyCategoryAggregateRepository()

    def ingest_events(
        self, db: Session, profile_id: str, payload: UsageIngestionRequest
    ) -> UsageIngestionResponse:
        duplicate_count = 0
        candidates = []
        seen_source_ids: set[str] = set()

        for event in payload.events:
            if event.source_event_id in seen_source_ids:
                duplicate_count += 1
                continue
            seen_source_ids.add(event.source_event_id)
            if (
                self.usage_repository.get_by_source_event_id(
                    db, profile_id, event.source_event_id
                )
                is not None
            ):
                duplicate_count += 1
                continue
            candidates.append(event)

        planned_fragments: list[
            tuple[UsageEventCreate, str, datetime, datetime]
        ] = []
        created_count = 0
        for event in candidates:
            started_at = event.started_at.astimezone(timezone.utc)
            ended_at = event.ended_at.astimezone(timezone.utc)
            overlaps = self.usage_repository.list_overlapping_for_app(
                db,
                profile_id,
                event.app_id,
                started_at,
                ended_at,
            )
            uncovered_fragments = self._subtract_stored_overlaps(
                started_at,
                ended_at,
                overlaps,
            )
            if not uncovered_fragments:
                duplicate_count += 1
                continue

            created_count += 1
            for index, (fragment_start, fragment_end) in enumerate(
                uncovered_fragments
            ):
                source_event_id = (
                    event.source_event_id
                    if index == 0
                    else self._fragment_source_event_id(
                        event.source_event_id,
                        fragment_start,
                        fragment_end,
                        index,
                    )
                )
                planned_fragments.append(
                    (event, source_event_id, fragment_start, fragment_end)
                )

        for event, source_event_id, started_at, ended_at in planned_fragments:
            self.usage_repository.create(
                db,
                profile_id=profile_id,
                app_id=event.app_id,
                app_name=event.app_name,
                category=normalize_category(event.category),
                source_event_id=source_event_id,
                started_at=started_at,
                ended_at=ended_at,
                duration_minutes=derive_duration_minutes(started_at, ended_at),
                timezone=event.timezone,
            )

        if planned_fragments:
            self._rebuild_aggregates_for_profile(db, profile_id)

        db.commit()
        return UsageIngestionResponse(
            received_count=len(payload.events),
            created_count=created_count,
            duplicate_count=duplicate_count,
        )

    @staticmethod
    def _subtract_stored_overlaps(
        started_at: datetime,
        ended_at: datetime,
        overlaps: Iterable[UsageEvent],
    ) -> list[tuple[datetime, datetime]]:
        remaining: list[tuple[datetime, datetime]] = []
        cursor = started_at
        normalized_overlaps = sorted(
            (
                UsageService._as_utc(overlap.started_at),
                UsageService._as_utc(overlap.ended_at),
            )
            for overlap in overlaps
        )

        for overlap_start, overlap_end in normalized_overlaps:
            covered_start = max(started_at, overlap_start)
            covered_end = min(ended_at, overlap_end)
            if covered_end <= cursor or covered_start >= ended_at:
                continue
            if covered_start > cursor:
                remaining.append((cursor, covered_start))
            cursor = max(cursor, covered_end)
            if cursor >= ended_at:
                break

        if cursor < ended_at:
            remaining.append((cursor, ended_at))
        return remaining

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)

    @staticmethod
    def _fragment_source_event_id(
        source_event_id: str,
        started_at: datetime,
        ended_at: datetime,
        index: int,
    ) -> str:
        fragment_key = (
            f"{source_event_id}|{started_at.isoformat()}|{ended_at.isoformat()}|{index}"
        )
        digest = sha256(fragment_key.encode("utf-8")).hexdigest()
        return f"server-fragment:{digest}"

    def rebuild_aggregates(
        self, db: Session, profile_id: str
    ) -> UsageAggregateRebuildResponse:
        event_count = self._rebuild_aggregates_for_profile(db, profile_id)
        db.commit()
        return UsageAggregateRebuildResponse(
            event_count=event_count,
            app_aggregate_count=self.app_aggregate_repository.count_for_profile(
                db, profile_id
            ),
            category_aggregate_count=(
                self.category_aggregate_repository.count_for_profile(db, profile_id)
            ),
        )

    def _rebuild_aggregates_for_profile(self, db: Session, profile_id: str) -> int:
        self.app_aggregate_repository.delete_for_profile(db, profile_id)
        self.category_aggregate_repository.delete_for_profile(db, profile_id)
        db.flush()

        app_milliseconds: dict[tuple, int] = defaultdict(int)
        app_names: dict[tuple, str] = {}
        category_milliseconds: dict[tuple, int] = defaultdict(int)
        events = self.usage_repository.list_all_for_profile(db, profile_id)

        for event in events:
            for usage_date, milliseconds in split_milliseconds_by_local_date(
                event.started_at,
                event.ended_at,
                event.timezone,
            ):
                app_key = (usage_date, event.app_id)
                app_milliseconds[app_key] += milliseconds
                app_names[app_key] = event.app_name
                category_milliseconds[(usage_date, event.category)] += milliseconds

        for (usage_date, app_id), milliseconds in app_milliseconds.items():
            self.app_aggregate_repository.add_minutes(
                db,
                profile_id=profile_id,
                usage_date=usage_date,
                app_id=app_id,
                app_name=app_names[(usage_date, app_id)],
                minutes=completed_minutes(milliseconds),
            )

        for (usage_date, category), milliseconds in category_milliseconds.items():
            self.category_aggregate_repository.add_minutes(
                db,
                profile_id=profile_id,
                usage_date=usage_date,
                category=category,
                minutes=completed_minutes(milliseconds),
            )

        return len(events)


usage_service = UsageService()
