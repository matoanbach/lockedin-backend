from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from lockedin_backend.core.authentication import AccessTokenClaims
from lockedin_backend.core.principal import CurrentPrincipal
from lockedin_backend.models import (
    Account,
    ExternalIdentity,
    Preferences,
    Profile,
    RevokedProviderSession,
    SecurityAuditEvent,
)
from lockedin_backend.repositories.identity_repository import IdentityRepository


class PrincipalRejected(RuntimeError):
    """Raised when valid provider claims do not map to an active LockdIn tenant."""


def as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class IdentityService:
    def __init__(self, repository: IdentityRepository | None = None) -> None:
        self.repository = repository or IdentityRepository()

    def _create_identity(
        self, db: Session, claims: AccessTokenClaims
    ) -> ExternalIdentity:
        profile = Profile(
            slug=f"account-{uuid4().hex}",
            name="LockdIn Account",
            is_demo=False,
            is_active=True,
        )
        account = Account(
            profile=profile,
            enabled=True,
            tokens_valid_after=claims.issued_at,
        )
        identity = ExternalIdentity(
            account=account,
            issuer=claims.issuer,
            subject=claims.subject,
        )
        db.add_all([profile, account, identity, Preferences(profile=profile)])
        db.flush()
        db.add(
            SecurityAuditEvent(
                event_type="account_provisioned",
                outcome="success",
                account_id=account.id,
                issuer=claims.issuer,
                provider_sid=claims.sid,
                source_category="provider",
            )
        )
        db.commit()
        return identity

    def resolve_principal(
        self,
        db: Session,
        claims: AccessTokenClaims,
        *,
        now: datetime | None = None,
        allow_provisioning: bool = True,
    ) -> CurrentPrincipal:
        identity = self.repository.get_external_identity(
            db, issuer=claims.issuer, subject=claims.subject
        )
        if identity is None:
            if not allow_provisioning:
                raise PrincipalRejected("Identity is unavailable")
            try:
                identity = self._create_identity(db, claims)
            except IntegrityError:
                db.rollback()
                identity = self.repository.get_external_identity(
                    db, issuer=claims.issuer, subject=claims.subject
                )
                if identity is None:
                    raise PrincipalRejected("Identity provisioning conflict")

        account = identity.account
        profile = account.profile
        current = now or datetime.now(timezone.utc)
        if not account.enabled or not profile.is_active or profile.is_demo:
            raise PrincipalRejected("Account or profile is unavailable")
        if claims.issued_at < as_utc(account.tokens_valid_after):
            raise PrincipalRejected("Credential predates the account revocation boundary")

        revoked = self.repository.get_revoked_session(
            db, issuer=claims.issuer, sid=claims.sid
        )
        if revoked is not None and as_utc(revoked.expires_at) > current:
            raise PrincipalRejected("Provider session is revoked")

        return CurrentPrincipal(
            account_id=account.id,
            profile_id=profile.id,
            issuer=claims.issuer,
            subject=claims.subject,
            sid=claims.sid,
        )


class AccountDeletionService:
    """Remove one account tenant while retaining only de-identified audit evidence."""

    def __init__(self, repository: IdentityRepository | None = None) -> None:
        self.repository = repository or IdentityRepository()

    def delete_account(self, db: Session, principal: CurrentPrincipal) -> None:
        account = self.repository.get_account(db, principal.account_id)
        if account is None or account.profile_id != principal.profile_id:
            raise PrincipalRejected("Account is unavailable")

        profile = account.profile
        audit_events = db.scalars(
            select(SecurityAuditEvent).where(
                SecurityAuditEvent.account_id == account.id
            )
        ).all()
        for audit_event in audit_events:
            audit_event.account_id = None
            audit_event.provider_sid = None
            audit_event.provider_event_id = None

        db.delete(account)
        db.flush()
        db.delete(profile)
        db.flush()
        db.add(
            SecurityAuditEvent(
                event_type="account_deleted",
                outcome="success",
                account_id=None,
                issuer=principal.issuer,
                provider_sid=None,
                provider_event_id=None,
                source_category="api",
            )
        )
        db.commit()


class SessionService:
    def __init__(
        self,
        repository: IdentityRepository | None = None,
        *,
        session_max_seconds: int = 8 * 60 * 60,
    ) -> None:
        self.repository = repository or IdentityRepository()
        self.session_max_seconds = session_max_seconds

    def _audit(
        self,
        db: Session,
        *,
        event_type: str,
        outcome: str,
        account_id: str | None,
        issuer: str | None,
        sid: str | None = None,
        provider_event_id: str | None = None,
        source_category: str = "api",
    ) -> None:
        db.add(
            SecurityAuditEvent(
                event_type=event_type,
                outcome=outcome,
                account_id=account_id,
                issuer=issuer,
                provider_sid=sid,
                provider_event_id=provider_event_id,
                source_category=source_category,
            )
        )

    def revoke_current_session(
        self,
        db: Session,
        principal: CurrentPrincipal,
        *,
        now: datetime | None = None,
        outcome: str = "success",
    ) -> None:
        if principal.sid is None:
            raise PrincipalRejected("Provider session identifier is required")
        current = now or datetime.now(timezone.utc)
        expires_at = current + timedelta(seconds=self.session_max_seconds)
        revoked = self.repository.get_revoked_session(
            db, issuer=principal.issuer, sid=principal.sid
        )
        if revoked is None:
            db.add(
                RevokedProviderSession(
                    account_id=principal.account_id,
                    issuer=principal.issuer,
                    sid=principal.sid,
                    revoked_at=current,
                    expires_at=expires_at,
                )
            )
        elif as_utc(revoked.expires_at) < expires_at:
            revoked.expires_at = expires_at
        self._audit(
            db,
            event_type="session_logout",
            outcome=outcome,
            account_id=principal.account_id,
            issuer=principal.issuer,
            sid=principal.sid,
        )
        db.commit()

    def revoke_all_sessions(
        self,
        db: Session,
        principal: CurrentPrincipal,
        *,
        now: datetime | None = None,
        outcome: str = "success",
    ) -> SecurityAuditEvent:
        account = self.repository.get_account(db, principal.account_id)
        if account is None:
            raise PrincipalRejected("Account is unavailable")
        current = now or datetime.now(timezone.utc)
        account.tokens_valid_after = current
        audit_event = SecurityAuditEvent(
            event_type="account_logout_all",
            outcome=outcome,
            account_id=account.id,
            issuer=principal.issuer,
            provider_sid=principal.sid,
            source_category="api",
        )
        db.add(audit_event)
        db.commit()
        return audit_event

    def set_audit_outcome(
        self, db: Session, audit_event: SecurityAuditEvent, outcome: str
    ) -> None:
        audit_event.outcome = outcome
        db.add(audit_event)
        db.commit()

    def process_provider_event(
        self,
        db: Session,
        *,
        issuer: str,
        subject: str,
        action: str,
        provider_event_id: str,
        occurred_at: datetime,
        outcome: str = "provider_pending",
    ) -> tuple[str | None, SecurityAuditEvent | None]:
        if self.repository.get_audit_event(db, provider_event_id) is not None:
            return None, None
        identity = self.repository.get_external_identity(
            db, issuer=issuer, subject=subject
        )
        if identity is None:
            audit_event = SecurityAuditEvent(
                event_type=action,
                outcome="ignored_unknown_identity",
                account_id=None,
                issuer=issuer,
                provider_event_id=provider_event_id,
                source_category="keycloak_event",
            )
            db.add(audit_event)
            db.commit()
            return None, audit_event

        account = identity.account
        if action in {"password_changed", "logout_all"}:
            account.tokens_valid_after = max(
                as_utc(account.tokens_valid_after), as_utc(occurred_at)
            )
        elif action == "account_disabled":
            account.enabled = False
            account.tokens_valid_after = max(
                as_utc(account.tokens_valid_after), as_utc(occurred_at)
            )
        else:
            raise PrincipalRejected("Unsupported provider event")
        audit_event = SecurityAuditEvent(
            event_type=action,
            outcome=outcome,
            account_id=account.id,
            issuer=issuer,
            provider_event_id=provider_event_id,
            source_category="keycloak_event",
        )
        db.add(audit_event)
        db.commit()
        return account.id, audit_event

    def process_backchannel_logout(
        self,
        db: Session,
        *,
        issuer: str,
        subject: str | None,
        sid: str | None,
        provider_event_id: str,
        occurred_at: datetime,
    ) -> None:
        if self.repository.get_audit_event(db, provider_event_id) is not None:
            return
        identity = (
            self.repository.get_external_identity(db, issuer=issuer, subject=subject)
            if subject is not None
            else None
        )
        if identity is None and sid is None:
            self._audit(
                db,
                event_type="provider_backchannel_logout",
                outcome="ignored_unknown_identity",
                account_id=None,
                issuer=issuer,
                sid=sid,
                provider_event_id=provider_event_id,
                source_category="keycloak_backchannel",
            )
            db.commit()
            return

        account = identity.account if identity is not None else None
        if sid is None and account is not None:
            account.tokens_valid_after = max(
                as_utc(account.tokens_valid_after), as_utc(occurred_at)
            )
        else:
            if sid is None:
                raise PrincipalRejected("Provider session identifier is required")
            expires_at = occurred_at + timedelta(seconds=self.session_max_seconds)
            revoked = self.repository.get_revoked_session(db, issuer=issuer, sid=sid)
            if revoked is None:
                db.add(
                    RevokedProviderSession(
                        account_id=account.id if account is not None else None,
                        issuer=issuer,
                        sid=sid,
                        revoked_at=occurred_at,
                        expires_at=expires_at,
                    )
                )
            elif account is not None and revoked.account_id not in {None, account.id}:
                raise PrincipalRejected("Provider session identity mismatch")
            elif as_utc(revoked.expires_at) < expires_at:
                revoked.expires_at = expires_at
        self._audit(
            db,
            event_type="provider_backchannel_logout",
            outcome="success",
            account_id=account.id if account is not None else None,
            issuer=issuer,
            sid=sid,
            provider_event_id=provider_event_id,
            source_category="keycloak_backchannel",
        )
        db.commit()
