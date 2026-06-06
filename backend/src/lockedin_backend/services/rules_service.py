from sqlalchemy.orm import Session

from lockedin_backend.core.errors import ConflictError, NotFoundError
from lockedin_backend.repositories.rule_repository import RuleRepository
from lockedin_backend.schemas.rules import RuleCreate, RuleResponse, RuleUpdate
from lockedin_backend.services.profile_context import profile_context_service


class RulesService:
    def __init__(self) -> None:
        self.repository = RuleRepository()

    def list_rules(self, db: Session) -> list[RuleResponse]:
        profile = profile_context_service.ensure_default_profile(db)
        rules = self.repository.list_by_profile_id(db, profile.id)
        return [RuleResponse.model_validate(rule) for rule in rules]

    def create_rule(self, db: Session, payload: RuleCreate) -> RuleResponse:
        profile = profile_context_service.ensure_default_profile(db)
        existing_rule = self.repository.get_by_app_id(db, profile.id, payload.app_id)
        if existing_rule is not None:
            raise ConflictError(f"Rule already exists for app_id '{payload.app_id}'")

        rule = self.repository.create(
            db,
            profile_id=profile.id,
            app_id=payload.app_id,
            app_name=payload.app_name,
            limit_minutes=payload.limit_minutes,
            enabled=payload.enabled,
        )
        db.commit()
        db.refresh(rule)
        return RuleResponse.model_validate(rule)

    def update_rule(self, db: Session, rule_id: str, payload: RuleUpdate) -> RuleResponse:
        profile = profile_context_service.ensure_default_profile(db)
        rule = self.repository.get_by_id(db, profile.id, rule_id)
        if rule is None:
            raise NotFoundError(f"Rule '{rule_id}' was not found")

        for field, value in payload.model_dump(exclude_none=True).items():
            setattr(rule, field, value)

        db.commit()
        db.refresh(rule)
        return RuleResponse.model_validate(rule)

    def delete_rule(self, db: Session, rule_id: str) -> None:
        profile = profile_context_service.ensure_default_profile(db)
        rule = self.repository.get_by_id(db, profile.id, rule_id)
        if rule is None:
            raise NotFoundError(f"Rule '{rule_id}' was not found")

        self.repository.delete(db, rule)
        db.commit()


rules_service = RulesService()
