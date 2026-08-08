from sqlalchemy.orm import Session

from lockedin_backend.core.errors import ConflictError, NotFoundError
from lockedin_backend.repositories.accountability_repository import AccountabilityRepository
from lockedin_backend.schemas.accountability import (
    AccountabilityContactCreate,
    AccountabilityContactResponse,
)


class AccountabilityService:
    def __init__(self) -> None:
        self.repository = AccountabilityRepository()

    def list_contacts(
        self, db: Session, profile_id: str
    ) -> list[AccountabilityContactResponse]:
        contacts = self.repository.list_by_profile_id(db, profile_id)
        return [AccountabilityContactResponse.model_validate(contact) for contact in contacts]

    def create_contact(
        self, db: Session, profile_id: str, payload: AccountabilityContactCreate
    ) -> AccountabilityContactResponse:
        normalized_email = payload.email.strip().lower()
        existing_contact = self.repository.get_by_email(db, profile_id, normalized_email)
        if existing_contact is not None:
            raise ConflictError(f"Accountability contact already exists for '{normalized_email}'")

        derived_name = payload.name.strip() if payload.name else normalized_email.split("@", 1)[0]
        contact = self.repository.create(
            db,
            profile_id=profile_id,
            name=derived_name,
            email=normalized_email,
            consent_confirmed=payload.consent_confirmed,
        )
        db.commit()
        db.refresh(contact)
        return AccountabilityContactResponse.model_validate(contact)

    def delete_contact(self, db: Session, profile_id: str, contact_id: str) -> None:
        contact = self.repository.get_by_id(db, profile_id, contact_id)
        if contact is None:
            raise NotFoundError(f"Accountability contact '{contact_id}' was not found")

        self.repository.delete(db, contact)
        db.commit()


accountability_service = AccountabilityService()
