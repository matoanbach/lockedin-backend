"""phase4 enforcement events

Revision ID: 20250606_000004
Revises: 20250606_000003
Create Date: 2026-06-06 00:00:04.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20250606_000004"
down_revision: str | None = "20250606_000003"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "enforcement_events",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("rule_id", sa.String(length=36), nullable=True),
        sa.Column("app_id", sa.String(length=255), nullable=False),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("usage_date", sa.Date(), nullable=False),
        sa.Column("used_minutes", sa.Integer(), nullable=False),
        sa.Column("limit_minutes", sa.Integer(), nullable=False),
        sa.Column("metadata_json", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
            name=op.f("fk_enforcement_events_profile_id_profiles"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["rule_id"],
            ["rules.id"],
            name=op.f("fk_enforcement_events_rule_id_rules"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_enforcement_events")),
    )
    op.create_index(
        "ix_enforcement_events_profile_usage_date",
        "enforcement_events",
        ["profile_id", "usage_date"],
        unique=False,
    )
    op.create_index(
        "ix_enforcement_events_profile_rule_created_at",
        "enforcement_events",
        ["profile_id", "rule_id", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_enforcement_events_profile_rule_created_at",
        table_name="enforcement_events",
    )
    op.drop_index(
        "ix_enforcement_events_profile_usage_date",
        table_name="enforcement_events",
    )
    op.drop_table("enforcement_events")
