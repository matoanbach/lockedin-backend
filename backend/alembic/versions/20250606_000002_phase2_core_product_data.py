"""phase2 core product data

Revision ID: 20250606_000002
Revises: 20250606_000001
Create Date: 2026-06-06 00:00:02.000000
"""

from collections.abc import Sequence
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa

from lockedin_backend.core.constants import (
    DEFAULT_DAILY_LIMIT_MINUTES,
    DEFAULT_NOTIFICATION_TONE,
    DEFAULT_PROFILE_NAME,
    DEFAULT_PROFILE_SLUG,
    DEFAULT_TEXT_SIZE_PERCENT,
)


revision: str = "20250606_000002"
down_revision: str | None = "20250606_000001"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "profiles",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("slug", sa.String(length=50), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_profiles")),
        sa.UniqueConstraint("slug", name=op.f("uq_profiles_slug")),
    )

    op.create_table(
        "preferences",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("has_completed_onboarding", sa.Boolean(), nullable=False),
        sa.Column("default_daily_limit_minutes", sa.Integer(), nullable=False),
        sa.Column("notification_tone", sa.String(length=32), nullable=False),
        sa.Column("text_size_percent", sa.Integer(), nullable=False),
        sa.Column("high_contrast", sa.Boolean(), nullable=False),
        sa.Column("large_tap_targets", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
            name=op.f("fk_preferences_profile_id_profiles"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_preferences")),
        sa.UniqueConstraint("profile_id", name=op.f("uq_preferences_profile_id")),
    )

    op.create_table(
        "rules",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("app_id", sa.String(length=255), nullable=False),
        sa.Column("app_name", sa.String(length=255), nullable=False),
        sa.Column("limit_minutes", sa.Integer(), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
            name=op.f("fk_rules_profile_id_profiles"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_rules")),
        sa.UniqueConstraint("profile_id", "app_id", name="uq_rules_profile_app"),
    )

    op.create_table(
        "accountability_contacts",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("consent_confirmed", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
            name=op.f("fk_accountability_contacts_profile_id_profiles"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_accountability_contacts")),
        sa.UniqueConstraint(
            "profile_id",
            "email",
            name="uq_accountability_contacts_profile_email",
        ),
    )

    profiles = sa.table(
        "profiles",
        sa.column("id", sa.String(length=36)),
        sa.column("slug", sa.String(length=50)),
        sa.column("name", sa.String(length=100)),
        sa.column("created_at", sa.DateTime(timezone=True)),
        sa.column("updated_at", sa.DateTime(timezone=True)),
    )
    preferences = sa.table(
        "preferences",
        sa.column("id", sa.String(length=36)),
        sa.column("profile_id", sa.String(length=36)),
        sa.column("has_completed_onboarding", sa.Boolean()),
        sa.column("default_daily_limit_minutes", sa.Integer()),
        sa.column("notification_tone", sa.String(length=32)),
        sa.column("text_size_percent", sa.Integer()),
        sa.column("high_contrast", sa.Boolean()),
        sa.column("large_tap_targets", sa.Boolean()),
        sa.column("created_at", sa.DateTime(timezone=True)),
        sa.column("updated_at", sa.DateTime(timezone=True)),
    )

    now = datetime.now(timezone.utc)
    default_profile_id = "00000000-0000-0000-0000-000000000001"
    default_preferences_id = "00000000-0000-0000-0000-000000000002"

    op.bulk_insert(
        profiles,
        [
            {
                "id": default_profile_id,
                "slug": DEFAULT_PROFILE_SLUG,
                "name": DEFAULT_PROFILE_NAME,
                "created_at": now,
                "updated_at": now,
            }
        ],
    )

    op.bulk_insert(
        preferences,
        [
            {
                "id": default_preferences_id,
                "profile_id": default_profile_id,
                "has_completed_onboarding": False,
                "default_daily_limit_minutes": DEFAULT_DAILY_LIMIT_MINUTES,
                "notification_tone": DEFAULT_NOTIFICATION_TONE,
                "text_size_percent": DEFAULT_TEXT_SIZE_PERCENT,
                "high_contrast": False,
                "large_tap_targets": False,
                "created_at": now,
                "updated_at": now,
            }
        ],
    )


def downgrade() -> None:
    op.drop_table("accountability_contacts")
    op.drop_table("rules")
    op.drop_table("preferences")
    op.drop_table("profiles")
