from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from lockedin_backend.db.base import Base, TimestampMixin, utc_now


class RevokedProviderSession(Base, TimestampMixin):
    __tablename__ = "revoked_provider_sessions"
    __table_args__ = (
        UniqueConstraint(
            "issuer", "sid", name="uq_revoked_provider_sessions_issuer_sid"
        ),
        CheckConstraint(
            "expires_at >= revoked_at",
            name="expires_not_before_revocation",
        ),
    )

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    account_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False
    )
    issuer: Mapped[str] = mapped_column(String(255), nullable=False)
    sid: Mapped[str] = mapped_column(String(255), nullable=False)
    revoked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    account = relationship("Account", back_populates="revoked_provider_sessions")
