from sqlalchemy import select
from sqlalchemy.orm import Session

from lockedin_backend.models import AccountabilityContact


class AccountabilityRepository:
    def list_by_profile_id(self, db: Session, profile_id: str) -> list[AccountabilityContact]:
        return list(
            db.execute(
                select(AccountabilityContact)
                .where(AccountabilityContact.profile_id == profile_id)
                .order_by(AccountabilityContact.email.asc())
            ).scalars()
        )

    def get_by_id(
        self, db: Session, profile_id: str, contact_id: str
    ) -> AccountabilityContact | None:
        return db.execute(
            select(AccountabilityContact).where(
                AccountabilityContact.profile_id == profile_id,
                AccountabilityContact.id == contact_id,
            )
        ).scalar_one_or_none()

    def get_by_email(
        self, db: Session, profile_id: str, email: str
    ) -> AccountabilityContact | None:
        return db.execute(
            select(AccountabilityContact).where(
                AccountabilityContact.profile_id == profile_id,
                AccountabilityContact.email == email,
            )
        ).scalar_one_or_none()

    def create(
        self,
        db: Session,
        *,
        profile_id: str,
        name: str,
        email: str,
        consent_confirmed: bool,
    ) -> AccountabilityContact:
        contact = AccountabilityContact(
            profile_id=profile_id,
            name=name,
            email=email,
            consent_confirmed=consent_confirmed,
        )
        db.add(contact)
        db.flush()
        return contact

    def delete(self, db: Session, contact: AccountabilityContact) -> None:
        db.delete(contact)
