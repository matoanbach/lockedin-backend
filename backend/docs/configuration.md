# Configuration

This page explains how the backend is configured locally and in Docker.

Path note:

- `backend/.env` and `backend/.env.example` are repo-root paths
- `conf/gunicorn.conf.py` and `src/lockedin_backend/...` are paths inside `backend/`

## Primary Env File

The main local env file is:

- `backend/.env`

Template:

- `backend/.env.example`

Create it if needed:

```bash
cp backend/.env.example backend/.env
```

## Source Files

- settings loader: `src/lockedin_backend/core/settings.py`
- Gunicorn runtime config: `conf/gunicorn.conf.py`
- env template: `.env.example`

## Important Variables

### App identity

- `APP_NAME`
- `APP_VERSION`
- `DEBUG`

These feed FastAPI settings loaded by `Settings` in `core/settings.py`.

### Backend runtime

- `BACKEND_PORT`
- `BACKEND_CONTAINER_PORT`
- `BIND`
- `WORKERS`
- `WORKER_CLASS`
- `LOGLEVEL`

These are mainly used by Docker Compose and Gunicorn.

### Database runtime

- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_PORT`
- `DATABASE_URL`
- `DOCKER_DATABASE_URL`

## Current Local Defaults

- backend port: `8000`
- Postgres host port: `5433`
- local DB URL: `postgresql+psycopg://postgres:postgres@localhost:5433/lockedin`

## Local Backend vs Docker Backend

### Local backend on your machine

Uses:

- `DATABASE_URL`

Default expected DB location:

- `localhost:5433`

### Backend-only Docker stack

Uses:

- `DOCKER_DATABASE_URL`

Default expected DB location:

- `host.docker.internal:5433`

### Full root compose stack

Uses a service-to-service internal DB URL:

- `postgresql+psycopg://postgres:postgres@postgres:5432/lockedin`

In that setup, the backend container talks to the `postgres` compose service directly.

## How Settings Are Loaded

`core/settings.py` defines a `Settings` class that:

- reads from `backend/.env`
- provides defaults when fields are missing
- exposes settings through `get_settings()`

Important current defaults:

- `debug = True`
- `database_url = postgresql+psycopg://postgres:postgres@localhost:5433/lockedin`

## Gunicorn Runtime Config

`conf/gunicorn.conf.py` reads runtime values from env:

- `BIND`
- `WORKERS`
- `WORKER_CLASS`
- `TIMEOUT`
- `LOGLEVEL`

The backend Docker image starts with:

```text
gunicorn -c conf/gunicorn.conf.py lockedin_backend.app.main:app
```

## Important Team Notes

- The backend is intentionally env-driven.
- Do not treat root `.env` files as the source of truth for backend runtime.
- For compose commands in this repo, use `--env-file backend/.env`.
- The backend assumes the database is already initialized and available.
- `/docs/` and `/api/docs` are separate endpoints with different purposes.

## Related Pages

- [Getting started](getting-started.md)
- [Deployment](deployment.md)
- [Architecture](architecture.md)
