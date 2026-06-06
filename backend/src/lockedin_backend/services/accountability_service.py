from sqlalchemy.orm import Session

from lockedin_backend.core.errors import ConflictError, NotFoundError
from lockedin_backend.repositories.accountability_repository import AccountabilityRepository
from lockedin_backend.schemas.accountability import (
    AccountabilityContactCreate,
    AccountabilityContactResponse,
)
from lockedin_backend.services.profile_context import profile_context_service


class AccountabilityService:
    def __init__(self) -> None:
        self.repository = AccountabilityRepository()

    def list_contacts(self, db: Session) -> list[AccountabilityContactResponse]:
        profile = profile_context_service.ensure_default_profile(db)
        contacts = self.repository.list_by_profile_id(db, profile.id)
        return [AccountabilityContactResponse.model_validate(contact) for contact in contacts]

    def create_contact(
        self, db: Session, payload: AccountabilityContactCreate
    ) -> AccountabilityContactResponse:
        profile = profile_context_service.ensure_default_profile(db)
        normalized_email = payload.email.strip().lower()
        existing_contact = self.repository.get_by_email(db, profile.id, normalized_email)
        if existing_contact is not None:
            raise ConflictError(f"Accountability contact already exists for '{normalized_email}'")

        derived_name = payload.name.strip() if payload.name else normalized_email.split("@", 1)[0]
        contact = self.repository.create(
            db,
            profile_id=profile.id,
            name=derived_name,
            email=normalized_email,
            consent_confirmed=payload.consent_confirmed,
        )
        db.commit()
        db.refresh(contact)
        return AccountabilityContactResponse.model_validate(contact)

    def delete_contact(self, db: Session, contact_id: str) -> None:
        profile = profile_context_service.ensure_default_profile(db)
        contact = self.repository.get_by_id(db, profile.id, contact_id)
        if contact is None:
            raise NotFoundError(f"Accountability contact '{contact_id}' was not found")

        self.repository.delete(db, contact)
        db.commit()


accountability_service = AccountabilityService()
