from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from lockedin_backend.models import UsageEvent


class UsageRepository:
    def get_by_source_event_id(
        self, db: Session, profile_id: str, source_event_id: str
    ) -> UsageEvent | None:
        return db.execute(
            select(UsageEvent).where(
                UsageEvent.profile_id == profile_id,
                UsageEvent.source_event_id == source_event_id,
            )
        ).scalar_one_or_none()

    def create(
        self,
        db: Session,
        *,
        profile_id: str,
        app_id: str,
        app_name: str,
        category: str,
        source_event_id: str,
        started_at: datetime,
        ended_at: datetime,
        duration_minutes: int,
        timezone: str,
    ) -> UsageEvent:
        usage_event = UsageEvent(
            profile_id=profile_id,
            app_id=app_id,
            app_name=app_name,
            category=category,
            source_event_id=source_event_id,
            started_at=started_at,
            ended_at=ended_at,
            duration_minutes=duration_minutes,
            timezone=timezone,
        )
        db.add(usage_event)
        db.flush()
        return usage_event

    def list_overlapping_range(
        self,
        db: Session,
        profile_id: str,
        started_at: datetime,
        ended_at: datetime,
    ) -> list[UsageEvent]:
        return list(
            db.execute(
                select(UsageEvent)
                .where(
                    UsageEvent.profile_id == profile_id,
                    UsageEvent.started_at < ended_at,
                    UsageEvent.ended_at > started_at,
                )
                .order_by(UsageEvent.started_at.asc())
            ).scalars()
        )

    def get_latest_timezone(self, db: Session, profile_id: str) -> str | None:
        return db.execute(
            select(UsageEvent.timezone)
            .where(UsageEvent.profile_id == profile_id)
            .order_by(UsageEvent.started_at.desc())
            .limit(1)
        ).scalar_one_or_none()
