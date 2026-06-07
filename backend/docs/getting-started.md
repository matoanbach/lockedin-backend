# Getting Started

This page gets a new backend contributor to a first successful local run as quickly as possible.

Path note:

- commands that reference `backend/.env` assume you are starting from the repo root
- commands that start with `cd backend` assume you then run the following commands from `backend/`

If you want the shortest path to a running backend, use the full-stack flow first.

## What You Need

- Docker Desktop with `docker compose`
- Python 3.11+ if you want to run the backend outside Docker
- this repo checked out locally

## Recommended Fast Path

Start the full backend + database stack from the repo root:

```bash
docker compose --env-file backend/.env up -d --build
```

This gives you:

- backend on `http://127.0.0.1:8000`
- Postgres on `localhost:5433`

## Backend On Your Machine, Database In Docker

If you want a normal local Python development loop:

Start from the repo root:

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
cd backend
make install-venv
make init-env
make run
```

This is a good default workflow when changing backend code.

## Backend-Only Docker

If the database is already running separately:

Start from the repo root:

```bash
docker compose -f backend/docker-compose.yml --env-file backend/.env up -d --build
```

That container uses `DOCKER_DATABASE_URL` from `backend/.env`.

## First Successful Checks

Check the root endpoint:

```bash
curl http://127.0.0.1:8000/
```

Expected shape:

```json
{"message":"LockdIn Backend is running"}
```

Check health:

```bash
curl http://127.0.0.1:8000/api/v1/health
```

Build and open the backend docs site:

```bash
cd backend
make build-docs
```

Then open:

- docs site: `http://127.0.0.1:8000/docs/`
- Swagger UI: `http://127.0.0.1:8000/api/docs`

Use the static docs site for onboarding and architecture. Use Swagger UI for live endpoint inspection.

Check a live API route:

```bash
curl http://127.0.0.1:8000/api/v1/rules
```

## Test Commands

Run from `backend/`:

```bash
make test
make test-postgres
```

Use `make test` for the normal development test loop.

Use `make test-postgres` when you want to validate the live Postgres-backed local stack.

## Common Setup Failures

### Backend cannot connect to the database

Check that Postgres is running on `localhost:5433` and that `DATABASE_URL` in `backend/.env` points there.

### Port `5433` is not available

The current local workflow assumes Postgres is exposed on host port `5433`. Update `backend/.env` if your machine uses a different port.

### `backend/.env` is missing

Create it from the template:

```bash
cp backend/.env.example backend/.env
```

### Backend starts but data looks empty or wrong

The backend assumes the database is already initialized. Recreate the database stack if needed:

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env down -v
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
```

## Where To Go Next

- [Architecture](architecture.md)
- [Layers](layers.md)
- [Configuration](configuration.md)
- [Testing](testing.md)

A good next step is to open `src/lockedin_backend/app/main.py` and `src/lockedin_backend/api/router.py` alongside the Architecture and Layers pages.
