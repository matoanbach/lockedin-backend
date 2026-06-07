from sqlalchemy.orm import Session

from lockedin_backend.core.errors import NotFoundError
from lockedin_backend.repositories.enforcement_event_repository import (
    EnforcementEventRepository,
)
from lockedin_backend.repositories.rule_repository import RuleRepository
from lockedin_backend.schemas.enforcement import (
    EnforcementEventCreate,
    EnforcementEventResponse,
)
from lockedin_backend.services.profile_context import profile_context_service


class EnforcementService:
    def __init__(self) -> None:
        self.repository = EnforcementEventRepository()
        self.rule_repository = RuleRepository()

    def create_event(
        self, db: Session, payload: EnforcementEventCreate
    ) -> EnforcementEventResponse:
        profile = profile_context_service.ensure_default_profile(db)

        if payload.rule_id is not None:
            rule = self.rule_repository.get_by_id(db, profile.id, payload.rule_id)
            if rule is None:
                raise NotFoundError(f"Rule '{payload.rule_id}' was not found")

        enforcement_event = self.repository.create(
            db,
            profile_id=profile.id,
            rule_id=payload.rule_id,
            app_id=payload.app_id,
            event_type=payload.event_type,
            usage_date=payload.usage_date,
            used_minutes=payload.used_minutes,
            limit_minutes=payload.limit_minutes,
            metadata=payload.metadata,
        )
        db.commit()
        db.refresh(enforcement_event)
        return EnforcementEventResponse.model_validate(enforcement_event)


enforcement_service = EnforcementService()
