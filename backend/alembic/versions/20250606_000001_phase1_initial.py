"""phase1 initial

Revision ID: 20250606_000001
Revises:
Create Date: 2026-06-06 00:00:01.000000
"""

from collections.abc import Sequence


revision: str = "20250606_000001"
down_revision: str | None = None
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
