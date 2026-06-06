from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Boolean, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from lockedin_backend.core.constants import (
    DEFAULT_DAILY_LIMIT_MINUTES,
    DEFAULT_NOTIFICATION_TONE,
    DEFAULT_TEXT_SIZE_PERCENT,
)
from lockedin_backend.db.base import Base, TimestampMixin


class Preferences(Base, TimestampMixin):
    __tablename__ = "preferences"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    profile_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("profiles.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    has_completed_onboarding: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    default_daily_limit_minutes: Mapped[int] = mapped_column(
        Integer, default=DEFAULT_DAILY_LIMIT_MINUTES, nullable=False
    )
    notification_tone: Mapped[str] = mapped_column(
        String(32), default=DEFAULT_NOTIFICATION_TONE, nullable=False
    )
    text_size_percent: Mapped[int] = mapped_column(
        Integer, default=DEFAULT_TEXT_SIZE_PERCENT, nullable=False
    )
    high_contrast: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    large_tap_targets: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    profile = relationship("Profile", back_populates="preferences")
