# LockdIn Database

This directory owns the PostgreSQL schema snapshot and repeatable development seed data.

## Files

- `docker-compose.yml`: database-only container stack
- `.env.example`: database defaults
- `initdb/00-extensions.sql`: required extensions
- `initdb/10-schema.sql`: tables, constraints, and indexes
- `initdb/20-seed.sql`: synthetic default-profile, rule, usage, contact, and enforcement data

Backend ORM changes and `initdb/10-schema.sql` must stay aligned. The project does not currently use
a migration framework.

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
