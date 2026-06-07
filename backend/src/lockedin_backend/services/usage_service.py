from datetime import timezone

from sqlalchemy.orm import Session

from lockedin_backend.repositories.usage_daily_app_aggregate_repository import (
    UsageDailyAppAggregateRepository,
)
from lockedin_backend.repositories.usage_daily_category_aggregate_repository import (
    UsageDailyCategoryAggregateRepository,
)
from lockedin_backend.repositories.usage_repository import UsageRepository
from lockedin_backend.schemas.usage import UsageIngestionRequest, UsageIngestionResponse
from lockedin_backend.services.profile_context import profile_context_service
from lockedin_backend.services.usage_time import (
    derive_duration_minutes,
    normalize_category,
    split_minutes_by_local_date,
)


class UsageService:
    def __init__(self) -> None:
        self.usage_repository = UsageRepository()
        self.app_aggregate_repository = UsageDailyAppAggregateRepository()
        self.category_aggregate_repository = UsageDailyCategoryAggregateRepository()

    def ingest_events(
        self, db: Session, payload: UsageIngestionRequest
    ) -> UsageIngestionResponse:
        profile = profile_context_service.ensure_default_profile(db)
        created_count = 0
        duplicate_count = 0

        for event in payload.events:
            if (
                self.usage_repository.get_by_source_event_id(
                    db, profile.id, event.source_event_id
                )
                is not None
            ):
                duplicate_count += 1
                continue

            started_at = event.started_at.astimezone(timezone.utc)
            ended_at = event.ended_at.astimezone(timezone.utc)
            category = normalize_category(event.category)
            duration_minutes = derive_duration_minutes(started_at, ended_at)

            self.usage_repository.create(
                db,
                profile_id=profile.id,
                app_id=event.app_id,
                app_name=event.app_name,
                category=category,
                source_event_id=event.source_event_id,
                started_at=started_at,
                ended_at=ended_at,
                duration_minutes=duration_minutes,
                timezone=event.timezone,
            )

            for usage_date, minutes in split_minutes_by_local_date(
                started_at,
                ended_at,
                event.timezone,
            ):
                self.app_aggregate_repository.add_minutes(
                    db,
                    profile_id=profile.id,
                    usage_date=usage_date,
                    app_id=event.app_id,
                    app_name=event.app_name,
                    minutes=minutes,
                )
                self.category_aggregate_repository.add_minutes(
                    db,
                    profile_id=profile.id,
                    usage_date=usage_date,
                    category=category,
                    minutes=minutes,
                )

            created_count += 1

        db.commit()
        return UsageIngestionResponse(
            received_count=len(payload.events),
            created_count=created_count,
            duplicate_count=duplicate_count,
        )


usage_service = UsageService()
