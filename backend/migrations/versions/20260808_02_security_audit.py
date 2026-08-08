"""Add the redacted security audit event registry.

Revision ID: 20260808_02
Revises: 20260803_01
"""

from alembic import op
import sqlalchemy as sa


revision = "20260808_02"
down_revision = "20260803_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        raise RuntimeError("LockdIn migrations support PostgreSQL only")

    op.alter_column(
        "revoked_provider_sessions",
        "account_id",
        existing_type=sa.String(length=36),
        nullable=True,
    )
    op.create_table(
        "security_audit_events",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("outcome", sa.String(length=32), nullable=False),
        sa.Column("account_id", sa.String(length=36), nullable=True),
        sa.Column("issuer", sa.String(length=255), nullable=True),
        sa.Column("provider_sid", sa.String(length=255), nullable=True),
        sa.Column("provider_event_id", sa.String(length=255), nullable=True),
        sa.Column(
            "source_category",
            sa.String(length=32),
            nullable=False,
            server_default="provider",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["account_id"],
            ["accounts.id"],
            name="fk_security_audit_events_account_id_accounts",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_security_audit_events"),
        sa.UniqueConstraint(
            "provider_event_id", name="uq_security_audit_events_provider_event_id"
        ),
    )
    op.create_index(
        "ix_security_audit_events_account_created_at",
        "security_audit_events",
        ["account_id", "created_at"],
    )
    op.create_index(
        "ix_security_audit_events_type_created_at",
        "security_audit_events",
        ["event_type", "created_at"],
    )


def downgrade() -> None:
    raise RuntimeError("Destructive downgrade is intentionally unsupported")
