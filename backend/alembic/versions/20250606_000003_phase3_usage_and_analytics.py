"""phase3 usage and analytics

Revision ID: 20250606_000003
Revises: 20250606_000002
Create Date: 2026-06-06 00:00:03.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20250606_000003"
down_revision: str | None = "20250606_000002"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "usage_events",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("app_id", sa.String(length=255), nullable=False),
        sa.Column("app_name", sa.String(length=255), nullable=False),
        sa.Column("category", sa.String(length=100), nullable=False),
        sa.Column("source_event_id", sa.String(length=255), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), nullable=False),
        sa.Column("timezone", sa.String(length=100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
            name=op.f("fk_usage_events_profile_id_profiles"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_usage_events")),
        sa.UniqueConstraint(
            "profile_id",
            "source_event_id",
            name="uq_usage_events_profile_source_event",
        ),
    )
    op.create_index(
        "ix_usage_events_profile_started_at",
        "usage_events",
        ["profile_id", "started_at"],
        unique=False,
    )

    op.create_table(
        "usage_daily_app_aggregates",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("usage_date", sa.Date(), nullable=False),
        sa.Column("app_id", sa.String(length=255), nullable=False),
        sa.Column("app_name", sa.String(length=255), nullable=False),
        sa.Column("total_minutes", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
            name=op.f("fk_usage_daily_app_aggregates_profile_id_profiles"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_usage_daily_app_aggregates")),
        sa.UniqueConstraint(
            "profile_id",
            "usage_date",
            "app_id",
            name="uq_usage_daily_app_aggregates_profile_date_app",
        ),
    )
    op.create_index(
        "ix_usage_daily_app_aggregates_profile_usage_date",
        "usage_daily_app_aggregates",
        ["profile_id", "usage_date"],
        unique=False,
    )

    op.create_table(
        "usage_daily_category_aggregates",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("usage_date", sa.Date(), nullable=False),
        sa.Column("category", sa.String(length=100), nullable=False),
        sa.Column("total_minutes", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
            name=op.f("fk_usage_daily_category_aggregates_profile_id_profiles"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "id", name=op.f("pk_usage_daily_category_aggregates")
        ),
        sa.UniqueConstraint(
            "profile_id",
            "usage_date",
            "category",
            name="uq_usage_daily_category_aggregates_profile_date_category",
        ),
    )
    op.create_index(
        "ix_usage_daily_category_aggregates_profile_usage_date",
        "usage_daily_category_aggregates",
        ["profile_id", "usage_date"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_usage_daily_category_aggregates_profile_usage_date",
        table_name="usage_daily_category_aggregates",
    )
    op.drop_table("usage_daily_category_aggregates")
    op.drop_index(
        "ix_usage_daily_app_aggregates_profile_usage_date",
        table_name="usage_daily_app_aggregates",
    )
    op.drop_table("usage_daily_app_aggregates")
    op.drop_index("ix_usage_events_profile_started_at", table_name="usage_events")
    op.drop_table("usage_events")
