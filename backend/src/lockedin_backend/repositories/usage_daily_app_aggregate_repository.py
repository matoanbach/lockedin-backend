from datetime import date

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from lockedin_backend.models import UsageDailyAppAggregate


class UsageDailyAppAggregateRepository:
    def delete_for_profile(self, db: Session, profile_id: str) -> None:
        db.execute(
            delete(UsageDailyAppAggregate).where(
                UsageDailyAppAggregate.profile_id == profile_id
            )
        )

    def count_for_profile(self, db: Session, profile_id: str) -> int:
        return int(
            db.scalar(
                select(func.count()).select_from(UsageDailyAppAggregate).where(
                    UsageDailyAppAggregate.profile_id == profile_id
                )
            )
            or 0
        )

    def get_by_keys(
        self, db: Session, profile_id: str, usage_date: date, app_id: str
    ) -> UsageDailyAppAggregate | None:
        return db.execute(
            select(UsageDailyAppAggregate).where(
                UsageDailyAppAggregate.profile_id == profile_id,
                UsageDailyAppAggregate.usage_date == usage_date,
                UsageDailyAppAggregate.app_id == app_id,
            )
        ).scalar_one_or_none()

    def add_minutes(
        self,
        db: Session,
        *,
        profile_id: str,
        usage_date: date,
        app_id: str,
        app_name: str,
        minutes: int,
    ) -> UsageDailyAppAggregate:
        aggregate = self.get_by_keys(db, profile_id, usage_date, app_id)
        if aggregate is None:
            aggregate = UsageDailyAppAggregate(
                profile_id=profile_id,
                usage_date=usage_date,
                app_id=app_id,
                app_name=app_name,
                total_minutes=minutes,
            )
            db.add(aggregate)
        else:
            aggregate.app_name = app_name
            aggregate.total_minutes += minutes

        db.flush()
        return aggregate

    def get_daily_minutes_by_app_ids(
        self,
        db: Session,
        profile_id: str,
        usage_date: date,
        app_ids: list[str],
    ) -> dict[str, int]:
        if not app_ids:
            return {}

        rows = db.execute(
            select(
                UsageDailyAppAggregate.app_id,
                UsageDailyAppAggregate.total_minutes,
            ).where(
                UsageDailyAppAggregate.profile_id == profile_id,
                UsageDailyAppAggregate.usage_date == usage_date,
                UsageDailyAppAggregate.app_id.in_(app_ids),
            )
        ).all()

        return {app_id: int(total_minutes) for app_id, total_minutes in rows}

    def list_top_apps_for_date_range(
        self,
        db: Session,
        profile_id: str,
        start_date: date,
        end_date: date,
        *,
        limit: int,
    ) -> list[tuple[str, str, int]]:
        total_minutes = func.sum(UsageDailyAppAggregate.total_minutes).label("total_minutes")
        rows = db.execute(
            select(
                UsageDailyAppAggregate.app_id,
                UsageDailyAppAggregate.app_name,
                total_minutes,
            )
            .where(
                UsageDailyAppAggregate.profile_id == profile_id,
                UsageDailyAppAggregate.usage_date >= start_date,
                UsageDailyAppAggregate.usage_date <= end_date,
            )
            .group_by(
                UsageDailyAppAggregate.app_id,
                UsageDailyAppAggregate.app_name,
            )
            .order_by(total_minutes.desc(), UsageDailyAppAggregate.app_name.asc())
            .limit(limit)
        ).all()

        return [(app_id, app_name, int(minutes)) for app_id, app_name, minutes in rows]
