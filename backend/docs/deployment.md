# Deployment

This page explains the current backend runtime and deployment shape.

It focuses on what exists today, not an ideal future production setup.

Use this page to understand how the backend is packaged and started today. Use `PHASE5.md` for the broader production-hardening backlog.

## Current Runtime Artifacts

- backend image: `backend/Dockerfile`
- Gunicorn config: `backend/conf/gunicorn.conf.py`
- backend-only compose: `backend/docker-compose.yml`
- full local stack compose: top-level `docker-compose.yml`
- MkDocs config for backend docs: `backend/conf/mkdocs.yml`

## Backend Docker Image

File:

- `backend/Dockerfile`

Current behavior:

- uses `python:3.12-slim`
- installs the backend package from `pyproject.toml`
- copies `conf/` and `src/`
- starts Gunicorn with a Uvicorn worker

Container command:

```text
gunicorn -c conf/gunicorn.conf.py lockedin_backend.app.main:app
```

## Gunicorn Runtime

File:

- `backend/conf/gunicorn.conf.py`

Current env-driven settings:

- `BIND`
- `WORKERS`
- `WORKER_CLASS`
- `TIMEOUT`
- `LOGLEVEL`

Logging currently goes to stdout/stderr.

## Full Stack Compose

File:

- top-level `docker-compose.yml`

Command:

```bash
docker compose --env-file backend/.env up -d --build
```

Behavior:

- starts Postgres
- waits for Postgres health
- starts backend
- backend container talks to Postgres on the internal compose network

## Backend-Only Compose

File:

- `backend/docker-compose.yml`

Command:

```bash
docker compose -f backend/docker-compose.yml --env-file backend/.env up -d --build
```

Behavior:

- starts only the backend container
- expects the database to already exist elsewhere
- uses `DOCKER_DATABASE_URL`

## Database Ownership Reminder

The backend does not initialize local Postgres by itself.

Local database bootstrap is owned by the top-level `database/` folder.

That means the deployment/runtime contract is currently:

- database is started and initialized first
- backend then connects through the appropriate runtime database URL

In practice that means:

- local backend on your machine uses `DATABASE_URL`
- backend-only Docker uses `DOCKER_DATABASE_URL`
- full root compose uses the internal compose Postgres service URL

## Current Production Gaps

The backend is deployable locally in Docker, but not fully production-hardened yet.

Current gaps include:

- no DB-aware readiness endpoint yet
- no auth or access protection yet
- no explicit production settings split yet
- limited deployment hardening and observability

Also note:

- `/docs/` only serves the built static docs site if `make build-docs` has been run
- `/api/docs` is still available separately for Swagger UI
- the current Docker image does not build the docs site into the image automatically

Those gaps are tracked more fully in `PHASE5.md`.

## Recommended Team Mental Model

Treat the current deployment posture as:

- local development ready
- Docker-runtime ready
- early production-planning stage

Do not assume the current compose files alone represent a complete production design.

## Related Pages

- [Configuration](configuration.md)
- [Getting started](getting-started.md)
- [Roadmap](roadmap.md)
