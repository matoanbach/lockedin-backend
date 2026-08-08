from __future__ import annotations

from uuid import uuid4

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from lockedin_backend.db.base import Base, TimestampMixin


class SecurityAuditEvent(Base, TimestampMixin):
    """Redacted security evidence containing identifiers, never credentials."""

    __tablename__ = "security_audit_events"
    __table_args__ = (
        UniqueConstraint(
            "provider_event_id", name="uq_security_audit_events_provider_event_id"
        ),
        Index(
            "ix_security_audit_events_account_created_at", "account_id", "created_at"
        ),
        Index(
            "ix_security_audit_events_type_created_at", "event_type", "created_at"
        ),
    )

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    outcome: Mapped[str] = mapped_column(String(32), nullable=False)
    account_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("accounts.id", ondelete="SET NULL"),
        nullable=True,
    )
    issuer: Mapped[str | None] = mapped_column(String(255), nullable=True)
    provider_sid: Mapped[str | None] = mapped_column(String(255), nullable=True)
    provider_event_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    source_category: Mapped[str] = mapped_column(
        String(32), nullable=False, default="provider"
    )
