from __future__ import annotations

from datetime import date
from uuid import uuid4

from sqlalchemy import Date, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from lockedin_backend.db.base import Base, TimestampMixin


class EnforcementEvent(Base, TimestampMixin):
    __tablename__ = "enforcement_events"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    profile_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False
    )
    rule_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("rules.id", ondelete="SET NULL"), nullable=True
    )
    app_id: Mapped[str] = mapped_column(String(255), nullable=False)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    usage_date: Mapped[date] = mapped_column(Date, nullable=False)
    used_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    limit_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    metadata_json: Mapped[str] = mapped_column(Text, nullable=False, default="{}")

    profile = relationship("Profile", back_populates="enforcement_events")
    rule = relationship("Rule", back_populates="enforcement_events")
