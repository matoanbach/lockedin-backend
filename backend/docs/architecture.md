# Architecture

The LockdIn backend is a modular monolith built as one FastAPI service.

It is intentionally simple right now:

- one Python service
- one HTTP API surface
- one database connection layer
- one codebase with separated internal layers

Short version:

- routes stay thin
- services own business logic
- repositories stay close to persistence
- models must stay aligned with the top-level SQL bootstrap

## High-Level Shape

- `app/`: application entrypoint and startup
- `api/`: HTTP routing layer
- `core/`: cross-cutting shared code
- `db/`: engine, session, declarative base
- `models/`: SQLAlchemy ORM models
- `schemas/`: API request/response models
- `repositories/`: persistence access helpers
- `services/`: business logic
- `tests/`: backend test suite

The import root is `src/lockedin_backend/`.

## Runtime Boundaries

The backend owns:

- HTTP request handling
- business logic
- ORM model definitions
- DB session usage
- API validation and response serialization

The backend does not own local schema bootstrap.

The top-level `database/` folder owns:

- Docker Postgres startup for local development
- SQL schema bootstrap
- seed data

That means schema changes must stay aligned between:

- `backend/src/lockedin_backend/models/`
- `database/initdb/10-schema.sql`

## Application Startup

File:

- `src/lockedin_backend/app/main.py`

Key behaviors:

- `create_app()` builds the FastAPI application
- the API router is mounted under `/api/v1`
- a root `/` endpoint returns a simple service message
- a lifespan hook ensures the default profile exists before serving requests

## Request Lifecycle

Typical request flow:

1. FastAPI receives an HTTP request.
2. A route function in `api/routes/*.py` validates the request payload using a schema.
3. The route gets a DB session via `Depends(get_db)`.
4. The route calls a service in `services/`.
5. The service coordinates repository access and business rules.
6. Repositories query or write SQLAlchemy models.
7. The service commits or refreshes entities if needed.
8. The route returns a schema response.

Most backend changes fit somewhere in those eight steps.

## Example Flow: Create Rule

Example files:

- route: `api/routes/rules.py`
- service: `services/rules_service.py`
- repository: `repositories/rule_repository.py`
- model: `models/rule.py`
- schema: `schemas/rules.py`

Flow:

1. `POST /api/v1/rules` receives a `RuleCreate` payload.
2. `create_rule()` in `api/routes/rules.py` calls `rules_service.create_rule()`.
3. `RulesService` ensures the default profile exists.
4. `RulesService` canonicalizes the app ID and checks for duplicate rules.
5. `RuleRepository.create()` inserts a `Rule` ORM object.
6. The service commits and refreshes it.
7. The response is returned as `RuleResponse`.

## Current Identity Model

There is no auth yet.

Instead, the backend currently works through a default profile model:

- `ProfileContextService` ensures a default profile exists
- the default profile slug is `default`
- many services operate against that profile automatically

This is a major onboarding detail. New teammates should not assume the API is multi-user yet.

## Serialization Model

Schema models inherit from `APIModel` in `core/serialization.py`.

That means:

- Python code uses snake_case
- API payloads and responses use camelCase aliases

Example:

- Python field: `limit_minutes`
- API field: `limitMinutes`

## Error Model

The backend currently uses simple application-level exceptions from `core/errors.py`, such as:

- `ConflictError`
- `NotFoundError`

Routes translate those into HTTP responses.

## Current Non-Goals

These are intentionally not part of the current active architecture:

- auth
- Supabase integration
- microservices
- Alembic-driven migrations

## Related Pages

- [Layers](layers.md)
- [Configuration](configuration.md)
- [Data model](data-model.md)
- [Deployment](deployment.md)
