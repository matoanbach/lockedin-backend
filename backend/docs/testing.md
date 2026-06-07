# Testing

This page explains the current backend test strategy and how to run the relevant test layers.

Short version:

- run `make test` during normal development
- run `make test-postgres` when DB/bootstrap behavior matters

## Test Layers

The backend currently has two main test modes.

### Default test suite

Command:

```bash
cd backend
make test
```

What it uses:

- temporary SQLite databases created by `tests/conftest.py`

What it is good for:

- route behavior
- service behavior
- request/response validation
- normal local development feedback

### Live Postgres smoke test

Command:

```bash
cd backend
make test-postgres
```

Default DB target:

- `postgresql+psycopg://postgres:postgres@localhost:5433/lockedin`

What it is good for:

- validating the local Docker Postgres stack
- validating that the backend can read the initialized SQL bootstrap

You can override the target DB with `TEST_DATABASE_URL`.

## Important Files

- fixtures: `tests/conftest.py`
- Postgres smoke test: `tests/test_postgres_integration.py`
- feature tests: `tests/test_rules.py`, `tests/test_usage.py`, `tests/test_analytics.py`, and related files

## Current Testing Strategy

### Why default tests use SQLite

The normal backend test loop is optimized for speed and isolation.

`tests/conftest.py`:

- creates a temporary SQLite database per test context
- creates tables from ORM metadata
- builds a test app with a test session factory

This keeps most tests fast and self-contained.

### Why there is a separate Postgres smoke test

The local runtime no longer centers on SQLite.

Because the real local environment uses Postgres initialized from top-level SQL files, `test_postgres_integration.py` exists to validate that environment separately.

## Recommended Team Workflow

During normal backend development:

```bash
cd backend
make test
```

When changing anything related to:

- database initialization
- SQL bootstrap
- Postgres-specific runtime behavior
- end-to-end local stack setup

also run:

```bash
cd backend
make test-postgres
```

This is the expected review baseline for changes that touch persistence or local stack setup.

## Gaps To Be Aware Of

- SQLite tests do not prove that the SQL bootstrap in `database/initdb/10-schema.sql` is fully aligned in every case.
- The current health check does not validate DB connectivity.
- Postgres smoke coverage is intentionally light right now.

## Related Pages

- [Getting started](getting-started.md)
- [Data model](data-model.md)
- [Deployment](deployment.md)
