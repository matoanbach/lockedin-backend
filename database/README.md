# Database

This folder owns local Postgres initialization for LockdIn.

The backend should treat this database as already initialized and only connect to it through `DATABASE_URL`.

## Files

- `docker-compose.yml`: starts the Postgres container
- `.env.example`: example Postgres container settings
- `initdb/00-extensions.sql`: optional Postgres extensions
- `initdb/10-schema.sql`: backend-compatible schema snapshot
- `initdb/20-seed.sql`: fake development data

## First-Time Setup

1. Optional: copy the env template if you want to override the default Postgres settings:

```bash
cp .env.example .env
```

If you skip that step, `docker compose` uses these defaults:
- database: `lockedin`
- user: `postgres`
- password: `postgres`
- host port: `5433`
- container port: `5432`

2. Start Postgres:

```bash
docker compose --env-file backend/.env up -d postgres
```

3. Point the backend at the database:

```text
postgresql+psycopg://postgres:postgres@localhost:5433/lockedin
```

Use that as `DATABASE_URL` unless you changed `.env`.

For the full local stack from the repo root:

```bash
docker compose --env-file backend/.env up -d
```

## Reinitialize The Database

The SQL files under `initdb/` only run when Postgres initializes a fresh data directory.

To rebuild from scratch:

```bash
docker compose down -v
docker compose up -d
```

## Notes

- schema changes in the backend must be reflected in `initdb/10-schema.sql`
- fake data changes should go in `initdb/20-seed.sql`
