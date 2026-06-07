# Backend Docs

This section is the onboarding and maintenance guide for the LockdIn backend.

It is written for teammates who need to:

- run the backend locally
- understand the architecture quickly
- find the right layer to change
- understand database ownership and runtime assumptions
- test and ship changes safely

Think of this docs set as the backend handoff guide for a new teammate.

Useful local URLs once the backend is running:

- static docs site: `http://127.0.0.1:8000/docs/`
- Swagger UI: `http://127.0.0.1:8000/api/docs`
- health: `http://127.0.0.1:8000/api/v1/health`

Important note:

- `/docs/` is the built static onboarding site
- `/api/docs` is FastAPI Swagger UI

## Start Here

Recommended reading order for new contributors:

1. [Getting started](getting-started.md)
2. [Architecture](architecture.md)
3. [Layers](layers.md)
4. [Configuration](configuration.md)
5. [API surface](api.md)
6. [Data model](data-model.md)
7. [Testing](testing.md)
8. [Deployment](deployment.md)
9. [Roadmap](roadmap.md)

If you are onboarding in one sitting, stop after [Layers](layers.md) first and then start reading code.

## Choose Your Path

### I want to run the backend locally

- [Getting started](getting-started.md)
- [Configuration](configuration.md)
- [Testing](testing.md)

### I want to understand the codebase structure

- [Architecture](architecture.md)
- [Layers](layers.md)
- [Data model](data-model.md)

### I want to change or add an endpoint

- [API surface](api.md)
- [Layers](layers.md)
- [Architecture](architecture.md)

### I want to validate against Postgres

- [Getting started](getting-started.md)
- [Testing](testing.md)
- [Data model](data-model.md)

### I want to understand the current deployment shape

- [Deployment](deployment.md)
- [Configuration](configuration.md)
- [Roadmap](roadmap.md)

## Current Backend Shape

- entrypoint: `src/lockedin_backend/app/main.py`
- API root: `/api/v1`
- package root: `src/lockedin_backend`
- local env file: `backend/.env`
- SQL bootstrap owner: top-level `database/`

Build the static docs site from `backend/` with:

```bash
make build-docs
```

## Important Current Assumptions

- the backend is a modular monolith, not a microservice system
- the app auto-creates a default profile on startup
- there is no auth yet
- the database schema is owned by SQL files under the top-level `database/initdb/`
- local Postgres uses host port `5433`

## Source Of Truth Notes

- Runtime behavior is defined by code under `src/lockedin_backend/`.
- Database bootstrap is defined by the top-level `database/` folder.
- Planning files like `PLAN.md` and `PHASE*.md` are useful context, but they are not the main operational runbooks.
