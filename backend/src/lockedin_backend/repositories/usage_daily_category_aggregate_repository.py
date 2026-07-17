from datetime import date

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from lockedin_backend.models import UsageDailyCategoryAggregate


class UsageDailyCategoryAggregateRepository:
    def delete_for_profile(self, db: Session, profile_id: str) -> None:
        db.execute(
            delete(UsageDailyCategoryAggregate).where(
                UsageDailyCategoryAggregate.profile_id == profile_id
            )
        )

    def count_for_profile(self, db: Session, profile_id: str) -> int:
        return int(
            db.scalar(
                select(func.count()).select_from(UsageDailyCategoryAggregate).where(
                    UsageDailyCategoryAggregate.profile_id == profile_id
                )
            )
            or 0
        )

    def get_by_keys(
        self, db: Session, profile_id: str, usage_date: date, category: str
    ) -> UsageDailyCategoryAggregate | None:
        return db.execute(
            select(UsageDailyCategoryAggregate).where(
                UsageDailyCategoryAggregate.profile_id == profile_id,
                UsageDailyCategoryAggregate.usage_date == usage_date,
                UsageDailyCategoryAggregate.category == category,
            )
        ).scalar_one_or_none()

    def add_minutes(
        self,
        db: Session,
        *,
        profile_id: str,
        usage_date: date,
        category: str,
        minutes: int,
    ) -> UsageDailyCategoryAggregate:
        aggregate = self.get_by_keys(db, profile_id, usage_date, category)
        if aggregate is None:
            aggregate = UsageDailyCategoryAggregate(
                profile_id=profile_id,
                usage_date=usage_date,
                category=category,
                total_minutes=minutes,
            )
            db.add(aggregate)
        else:
            aggregate.total_minutes += minutes

        db.flush()
        return aggregate

    def list_by_date(
        self, db: Session, profile_id: str, usage_date: date
    ) -> list[UsageDailyCategoryAggregate]:
        return list(
            db.execute(
                select(UsageDailyCategoryAggregate)
                .where(
                    UsageDailyCategoryAggregate.profile_id == profile_id,
                    UsageDailyCategoryAggregate.usage_date == usage_date,
                )
                .order_by(
                    UsageDailyCategoryAggregate.total_minutes.desc(),
                    UsageDailyCategoryAggregate.category.asc(),
                )
            ).scalars()
        )

    def get_daily_totals_for_date_range(
        self, db: Session, profile_id: str, start_date: date, end_date: date
    ) -> dict[date, int]:
        rows = db.execute(
            select(
                UsageDailyCategoryAggregate.usage_date,
                func.sum(UsageDailyCategoryAggregate.total_minutes),
            )
            .where(
                UsageDailyCategoryAggregate.profile_id == profile_id,
                UsageDailyCategoryAggregate.usage_date >= start_date,
                UsageDailyCategoryAggregate.usage_date <= end_date,
            )
            .group_by(UsageDailyCategoryAggregate.usage_date)
            .order_by(UsageDailyCategoryAggregate.usage_date.asc())
        ).all()

        return {usage_date: int(total_minutes) for usage_date, total_minutes in rows}

    def list_all_daily_totals(
        self, db: Session, profile_id: str
    ) -> list[tuple[date, int]]:
        rows = db.execute(
            select(
                UsageDailyCategoryAggregate.usage_date,
                func.sum(UsageDailyCategoryAggregate.total_minutes),
            )
            .where(UsageDailyCategoryAggregate.profile_id == profile_id)
            .group_by(UsageDailyCategoryAggregate.usage_date)
            .order_by(UsageDailyCategoryAggregate.usage_date.asc())
        ).all()

        return [(usage_date, int(total_minutes)) for usage_date, total_minutes in rows]
