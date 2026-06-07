from __future__ import annotations

from datetime import date
from uuid import uuid4

from sqlalchemy import Date, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from lockedin_backend.db.base import Base, TimestampMixin


class UsageDailyAppAggregate(Base, TimestampMixin):
    __tablename__ = "usage_daily_app_aggregates"
    __table_args__ = (
        UniqueConstraint(
            "profile_id",
            "usage_date",
            "app_id",
            name="uq_usage_daily_app_aggregates_profile_date_app",
        ),
        Index(
            "ix_usage_daily_app_aggregates_profile_usage_date",
            "profile_id",
            "usage_date",
        ),
    )

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    profile_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False
    )
    usage_date: Mapped[date] = mapped_column(Date, nullable=False)
    app_id: Mapped[str] = mapped_column(String(255), nullable=False)
    app_name: Mapped[str] = mapped_column(String(255), nullable=False)
    total_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    profile = relationship("Profile", back_populates="usage_daily_app_aggregates")
