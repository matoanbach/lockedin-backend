# Database migrations

Run migrations from `backend/` with `alembic upgrade head`. The first revision is deliberately
guarded: it creates the complete schema when no LockdIn tables exist, or verifies the exact legacy
schema before applying the additive tenant foundation. It refuses partial or ambiguous unversioned
schemas.

Destructive downgrade is intentionally unsupported. Operational rollback restores the previous
application while leaving additive Phase B structures in place; restore a verified backup only
when forward repair is unsafe.
