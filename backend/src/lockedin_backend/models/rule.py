from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Boolean, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from lockedin_backend.db.base import Base, TimestampMixin


class Rule(Base, TimestampMixin):
    __tablename__ = "rules"
    __table_args__ = (UniqueConstraint("profile_id", "app_id", name="uq_rules_profile_app"),)

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    profile_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False
    )
    app_id: Mapped[str] = mapped_column(String(255), nullable=False)
    app_name: Mapped[str] = mapped_column(String(255), nullable=False)
    limit_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    profile = relationship("Profile", back_populates="rules")
    enforcement_events = relationship("EnforcementEvent", back_populates="rule")
