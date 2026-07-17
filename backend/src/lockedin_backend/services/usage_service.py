import math
from collections import defaultdict
from datetime import timezone

from sqlalchemy.orm import Session

from lockedin_backend.repositories.usage_daily_app_aggregate_repository import (
    UsageDailyAppAggregateRepository,
)
from lockedin_backend.repositories.usage_daily_category_aggregate_repository import (
    UsageDailyCategoryAggregateRepository,
)
from lockedin_backend.repositories.usage_repository import UsageRepository
from lockedin_backend.schemas.usage import (
    UsageAggregateRebuildResponse,
    UsageIngestionRequest,
    UsageIngestionResponse,
)
from lockedin_backend.services.profile_context import profile_context_service
from lockedin_backend.services.usage_time import (
    derive_duration_minutes,
    normalize_category,
    split_seconds_by_local_date,
)


class UsageOverlapError(ValueError):
    pass


class UsageService:
    def __init__(self) -> None:
        self.usage_repository = UsageRepository()
        self.app_aggregate_repository = UsageDailyAppAggregateRepository()
        self.category_aggregate_repository = UsageDailyCategoryAggregateRepository()

    def ingest_events(
        self, db: Session, payload: UsageIngestionRequest
    ) -> UsageIngestionResponse:
        profile = profile_context_service.ensure_default_profile(db)
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
                    db, profile.id, event.source_event_id
                )
                is not None
            ):
                duplicate_count += 1
                continue
            candidates.append(event)

        # Validate the complete request before inserting anything so a conflict cannot leave a
        # partially accepted batch behind.
        for event in candidates:
            started_at = event.started_at.astimezone(timezone.utc)
            ended_at = event.ended_at.astimezone(timezone.utc)
            overlaps = self.usage_repository.list_overlapping_for_app(
                db,
                profile.id,
                event.app_id,
                started_at,
                ended_at,
            )
            if overlaps:
                raise UsageOverlapError(
                    f"Usage event {event.source_event_id!r} overlaps an existing "
                    f"event for app {event.app_id!r}"
                )

        for event in candidates:
            started_at = event.started_at.astimezone(timezone.utc)
            ended_at = event.ended_at.astimezone(timezone.utc)
            self.usage_repository.create(
                db,
                profile_id=profile.id,
                app_id=event.app_id,
                app_name=event.app_name,
                category=normalize_category(event.category),
                source_event_id=event.source_event_id,
                started_at=started_at,
                ended_at=ended_at,
                duration_minutes=derive_duration_minutes(started_at, ended_at),
                timezone=event.timezone,
            )

        if candidates:
            self._rebuild_aggregates_for_profile(db, profile.id)

        db.commit()
        return UsageIngestionResponse(
            received_count=len(payload.events),
            created_count=len(candidates),
            duplicate_count=duplicate_count,
        )

    def rebuild_aggregates(
        self, db: Session
    ) -> UsageAggregateRebuildResponse:
        profile = profile_context_service.ensure_default_profile(db)
        event_count = self._rebuild_aggregates_for_profile(db, profile.id)
        db.commit()
        return UsageAggregateRebuildResponse(
            event_count=event_count,
            app_aggregate_count=self.app_aggregate_repository.count_for_profile(
                db, profile.id
            ),
            category_aggregate_count=(
                self.category_aggregate_repository.count_for_profile(db, profile.id)
            ),
        )

    def _rebuild_aggregates_for_profile(self, db: Session, profile_id: str) -> int:
        self.app_aggregate_repository.delete_for_profile(db, profile_id)
        self.category_aggregate_repository.delete_for_profile(db, profile_id)
        db.flush()

        app_seconds: dict[tuple, float] = defaultdict(float)
        app_names: dict[tuple, str] = {}
        category_seconds: dict[tuple, float] = defaultdict(float)
        events = self.usage_repository.list_all_for_profile(db, profile_id)

        for event in events:
            for usage_date, seconds in split_seconds_by_local_date(
                event.started_at,
                event.ended_at,
                event.timezone,
            ):
                app_key = (usage_date, event.app_id)
                app_seconds[app_key] += seconds
                app_names[app_key] = event.app_name
                category_seconds[(usage_date, event.category)] += seconds

        for (usage_date, app_id), seconds in app_seconds.items():
            self.app_aggregate_repository.add_minutes(
                db,
                profile_id=profile_id,
                usage_date=usage_date,
                app_id=app_id,
                app_name=app_names[(usage_date, app_id)],
                minutes=math.ceil(seconds / 60),
            )

        for (usage_date, category), seconds in category_seconds.items():
            self.category_aggregate_repository.add_minutes(
                db,
                profile_id=profile_id,
                usage_date=usage_date,
                category=category,
                minutes=math.ceil(seconds / 60),
            )

        return len(events)


usage_service = UsageService()
