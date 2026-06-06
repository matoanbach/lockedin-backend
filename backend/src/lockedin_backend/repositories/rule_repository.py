from sqlalchemy import select
from sqlalchemy.orm import Session

from lockedin_backend.models import Rule


class RuleRepository:
    def list_by_profile_id(self, db: Session, profile_id: str) -> list[Rule]:
        return list(
            db.execute(
                select(Rule)
                .where(Rule.profile_id == profile_id)
                .order_by(Rule.app_name.asc())
            ).scalars()
        )

    def get_by_id(self, db: Session, profile_id: str, rule_id: str) -> Rule | None:
        return db.execute(
            select(Rule).where(Rule.profile_id == profile_id, Rule.id == rule_id)
        ).scalar_one_or_none()

    def get_by_app_id(self, db: Session, profile_id: str, app_id: str) -> Rule | None:
        return db.execute(
            select(Rule).where(Rule.profile_id == profile_id, Rule.app_id == app_id)
        ).scalar_one_or_none()

    def create(
        self,
        db: Session,
        *,
        profile_id: str,
        app_id: str,
        app_name: str,
        limit_minutes: int,
        enabled: bool,
    ) -> Rule:
        rule = Rule(
            profile_id=profile_id,
            app_id=app_id,
            app_name=app_name,
            limit_minutes=limit_minutes,
            enabled=enabled,
        )
        db.add(rule)
        db.flush()
        return rule

    def delete(self, db: Session, rule: Rule) -> None:
        db.delete(rule)
