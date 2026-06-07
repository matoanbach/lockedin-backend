from __future__ import annotations

from uuid import uuid4

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from lockedin_backend.db.base import Base, TimestampMixin


class Profile(Base, TimestampMixin):
    __tablename__ = "profiles"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    slug: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)

    preferences = relationship(
        "Preferences",
        back_populates="profile",
        cascade="all, delete-orphan",
        uselist=False,
    )
    rules = relationship(
        "Rule",
        back_populates="profile",
        cascade="all, delete-orphan",
    )
    accountability_contacts = relationship(
        "AccountabilityContact",
        back_populates="profile",
        cascade="all, delete-orphan",
    )
    usage_events = relationship(
        "UsageEvent",
        back_populates="profile",
        cascade="all, delete-orphan",
    )
    usage_daily_app_aggregates = relationship(
        "UsageDailyAppAggregate",
        back_populates="profile",
        cascade="all, delete-orphan",
    )
    usage_daily_category_aggregates = relationship(
        "UsageDailyCategoryAggregate",
        back_populates="profile",
        cascade="all, delete-orphan",
    )
    enforcement_events = relationship(
        "EnforcementEvent",
        back_populates="profile",
        cascade="all, delete-orphan",
    )
