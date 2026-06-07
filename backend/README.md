# LockdIn Backend

This directory contains the Python backend for LockdIn.

Current stack:

- FastAPI HTTP API
- SQLAlchemy ORM
- Postgres for local and containerized persistence
- Gunicorn + Uvicorn worker for container runtime

This backend is currently a modular monolith. It is intentionally simple:

- one service
- REST API only
- no auth yet
- one default profile created automatically at startup
- database schema bootstrap owned by the top-level `database/` folder

In these docs:

- paths like `backend/.env` are repo-root paths
- commands explicitly say whether they should be run from the repo root or from `backend/`

If you only read three pages first, read these:

1. [Getting started](docs/getting-started.md)
2. [Architecture](docs/architecture.md)
3. [Layers](docs/layers.md)

## Start Here

If you are new to the backend, read these in order:

1. [Docs home](docs/index.md)
2. [Getting started](docs/getting-started.md)
3. [Architecture](docs/architecture.md)
4. [Layers](docs/layers.md)
5. [Configuration](docs/configuration.md)

## Fastest Local Paths

### Full stack from the repo root

```bash
docker compose --env-file backend/.env up -d --build
```

### Database in Docker, backend on your machine

Start from the repo root:

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
cd backend
make install-venv
make init-env
make run
```

### Backend-only Docker against a separately running database

Start from the repo root:

```bash
docker compose -f backend/docker-compose.yml --env-file backend/.env up -d --build
```

## Useful Commands

Run from `backend/`:

```bash
cd backend
make install-venv
make init-env
make run
make test
make test-postgres
```

## Useful URLs

- root: `http://127.0.0.1:8000/`
- health: `http://127.0.0.1:8000/api/v1/health`
- rules: `http://127.0.0.1:8000/api/v1/rules`
- docs site: `http://127.0.0.1:8000/docs/`
- Swagger UI: `http://127.0.0.1:8000/api/docs`

`/docs/` serves the backend onboarding site. `/api/docs` serves FastAPI Swagger UI.

Build the docs site before using `/docs/`:

```bash
cd backend
make build-docs
```

## Important Current Constraints

- Local Postgres is exposed on host port `5433`, not `5432`.
- The backend reads `DATABASE_URL` from `backend/.env`.
- The top-level `database/` folder owns SQL bootstrap and seed data.
- Alembic is not part of the active workflow.
- Most backend tests use SQLite fixtures by default; Postgres validation is a separate smoke test.
- The current runtime is effectively single-profile through automatic default-profile creation.

## Docs Map

- [Docs home](docs/index.md)
- [Getting started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Layers](docs/layers.md)
- [Configuration](docs/configuration.md)
- [API surface](docs/api.md)
- [Data model](docs/data-model.md)
- [Testing](docs/testing.md)
- [Deployment](docs/deployment.md)
- [Roadmap and planning](docs/roadmap.md)

## Planning Docs

These files are useful context, but they are not the primary onboarding path:

- [PLAN.md](PLAN.md)
- [PHASE1.md](PHASE1.md)
- [PHASE2.md](PHASE2.md)
- [PHASE3.md](PHASE3.md)
- [PHASE4.md](PHASE4.md)
- [PHASE5.md](PHASE5.md)

Treat the docs under `backend/docs/` as the operational handoff set for ongoing development.
