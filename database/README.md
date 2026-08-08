# LockdIn Database

This directory owns the PostgreSQL schema snapshot and repeatable development seed data.

## Files

- `docker-compose.yml`: database-only container stack
- `.env.example`: database defaults
- `initdb/00-extensions.sql`: required extensions
- `initdb/10-schema.sql`: tables, constraints, and indexes
- `initdb/15-migration-head.sql`: records the fresh snapshot at Alembic head `20260803_01`
- `initdb/20-seed.sql`: synthetic default-profile, rule, usage, contact, and enforcement data

Backend ORM models, Alembic revisions, `10-schema.sql`, and the recorded bootstrap head must stay
aligned. Alembic 1.18.5 is pinned in `backend/pyproject.toml` and `backend/uv.lock`.

## Migration Behavior

Run from `backend/`:

```powershell
.\.venv\Scripts\python.exe -m alembic heads
.\.venv\Scripts\python.exe -m alembic current
.\.venv\Scripts\python.exe -m alembic upgrade head
```

Revision `20260803_01` creates the complete schema on an empty database. An unversioned database
must exactly match the eight-table legacy schema before the additive tenant foundation is applied.
Partial, unexpected, or already-modified unversioned schemas fail closed. Do not use `alembic
stamp` to bypass this verification. Fresh Docker initialization runs `10-schema.sql` and then
`15-migration-head.sql`, so it starts at the same head without replaying the revision.

The migration adds `profiles.is_demo`, `profiles.is_active`, `accounts`, `external_identities`, and
`revoked_provider_sessions`. It marks the legacy `default` profile as demo-only, adds no account
for it, and does not rebuild aggregates or rewrite behavioral/history rows. PostgreSQL triggers
enforce that demo profiles cannot be account-owned.

## Backup, Restore Check, and Rollback

Before upgrading a database with existing data, record non-sensitive table counts and create a
custom-format backup to an operator-controlled path outside the repository:

```powershell
pg_dump --format=custom --no-owner --no-acl --file <backup-path> <database-url>
pg_restore --list <backup-path>
```

Verify the backup by restoring into a newly created, isolated database—not over the source:

```powershell
createdb <restore-check-database>
pg_restore --exit-on-error --single-transaction --no-owner --no-acl --dbname <restore-check-database> <backup-path>
```

Compare counts and referential-integrity checks for profiles, preferences, rules, contacts, raw
usage, both aggregate tables, and enforcement events. Never put a password in shell history or a
checked-in command; use the operator's approved PostgreSQL credential mechanism.

Destructive Alembic downgrade is intentionally unsupported. Before Phase C writes identity data,
rollback means restore the previous application and leave the additive tables/columns in place.
If forward repair is unsafe, preserve the failed database for diagnosis and restore the verified
backup to a controlled replacement database. Do not delete the original volume as rollback.

## Start Without Deleting Data

From the repository root:

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
docker compose -f database/docker-compose.yml --env-file backend/.env ps
```

Defaults:

- database: `lockedin`
- user: `postgres`
- host port: `5433`
- container port: `5432`

The local backend URL is:

```text
postgresql+psycopg://postgres:postgres@localhost:5433/lockedin
```

Change development credentials before any non-local deployment.

## Seed Behavior

The SQL under `initdb/` runs only when PostgreSQL initializes a new, empty data directory. Seed
inserts use stable IDs or conflict handling so a controlled re-execution does not duplicate the
main demo entities.

The fixed default profile is explicitly `is_demo = TRUE` and remains unowned.

## Destructive Reinitialization

Removing the Docker volume deletes every LockdIn profile, preference, rule, contact, raw usage
event, aggregate, and enforcement event stored there.

Do not run a volume reset as routine troubleshooting. First inspect the exact compose project,
volume, container health, logs, connection settings, and row counts. Show what will be deleted and
obtain approval from the data owner immediately before a reset.

Only after that approval, the database-only reset is:

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env down -v
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
```

For non-destructive aggregate recovery, use the documented backend rebuild endpoint only after
reviewing its impact. It rewrites derived aggregates but preserves raw usage events.
