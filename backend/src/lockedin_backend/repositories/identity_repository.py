from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from lockedin_backend.models import (
    Account,
    ExternalIdentity,
    RevokedProviderSession,
    SecurityAuditEvent,
)


class IdentityRepository:
    def get_external_identity(
        self, db: Session, *, issuer: str, subject: str
    ) -> ExternalIdentity | None:
        return db.execute(
            select(ExternalIdentity)
            .options(joinedload(ExternalIdentity.account).joinedload(Account.profile))
            .where(
                ExternalIdentity.issuer == issuer,
                ExternalIdentity.subject == subject,
            )
        ).scalar_one_or_none()

    def get_account(self, db: Session, account_id: str) -> Account | None:
        return db.get(Account, account_id)

    def get_revoked_session(
        self, db: Session, *, issuer: str, sid: str
    ) -> RevokedProviderSession | None:
        return db.execute(
            select(RevokedProviderSession).where(
                RevokedProviderSession.issuer == issuer,
                RevokedProviderSession.sid == sid,
            )
        ).scalar_one_or_none()

    def get_audit_event(
        self, db: Session, provider_event_id: str
    ) -> SecurityAuditEvent | None:
        return db.execute(
            select(SecurityAuditEvent).where(
                SecurityAuditEvent.provider_event_id == provider_event_id
            )
        ).scalar_one_or_none()
