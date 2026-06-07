# Layers

This page explains the backend package layout and what belongs in each layer.

The goal is to help new contributors quickly answer:

- where should I make this change?
- what should this layer be responsible for?
- what should not go here?

Default rule for new code:

- keep routes thin
- keep repositories thin
- put business decisions in services

## Package Root

Everything lives under:

- `src/lockedin_backend/`

## `app/`

Purpose:

- top-level application setup

Current file:

- `src/lockedin_backend/app/main.py`

Responsibilities:

- create the FastAPI app
- register routers
- define root routes
- run startup/lifespan behavior
- attach the session factory to app state

Do put here:

- app construction
- startup/lifespan wiring
- app-wide registration

Do not put here:

- feature business logic
- direct query logic for one endpoint

## `api/`

Purpose:

- HTTP routing and transport concerns

Current files:

- `src/lockedin_backend/api/router.py`
- `src/lockedin_backend/api/routes/*.py`

Responsibilities:

- define route paths and HTTP verbs
- accept validated request payloads
- depend on DB sessions
- map application errors to HTTP errors
- return schema responses

Do put here:

- route functions
- FastAPI `Depends(...)`
- HTTP status code behavior
- transport-level exception mapping

Do not put here:

- multi-step domain logic
- raw persistence orchestration

## `core/`

Purpose:

- shared cross-cutting helpers and base behavior

Current files:

- `core/settings.py`
- `core/serialization.py`
- `core/errors.py`
- `core/constants.py`

Responsibilities:

- environment-driven settings
- serialization defaults
- shared error types
- stable constants

Do put here:

- things that multiple features need
- app-wide settings or helper behavior

Do not put here:

- feature-specific workflow logic
- database query code

## `db/`

Purpose:

- foundational SQLAlchemy setup

Current files:

- `db/base.py`
- `db/session.py`

Responsibilities:

- declarative base
- timestamp mixin
- naming conventions
- engine creation
- session factory creation
- request-scoped DB dependency

Do put here:

- generic DB/session setup

Do not put here:

- model definitions
- feature queries

## `models/`

Purpose:

- SQLAlchemy ORM mappings for persisted entities

Current entities include:

- `Profile`
- `Preferences`
- `Rule`
- `UsageEvent`
- `UsageDailyAppAggregate`
- `UsageDailyCategoryAggregate`
- `AccountabilityContact`
- `EnforcementEvent`

Responsibilities:

- table shape
- constraints and indexes
- ORM relationships

Do put here:

- ORM columns and relationships
- uniqueness/index definitions

Do not put here:

- business logic branching
- request validation behavior

## `schemas/`

Purpose:

- API request and response contracts

Responsibilities:

- payload validation
- response typing
- camelCase API aliases through `APIModel`

Do put here:

- `RuleCreate`, `RuleResponse`, `UsageIngestionRequest`, and similar API models

Do not put here:

- ORM relationships
- SQLAlchemy query logic

## `repositories/`

Purpose:

- thin persistence access layer

Example:

- `repositories/rule_repository.py`

Responsibilities:

- select/query helpers
- create/delete persistence helpers
- small, reusable DB access methods

Do put here:

- focused DB access methods
- repeated query patterns

Do not put here:

- HTTP concerns
- multi-step business workflows
- user-facing response formatting

## `services/`

Purpose:

- business logic and orchestration layer

Examples:

- `rules_service.py`
- `usage_service.py`
- `analytics_service.py`
- `profile_context.py`

Responsibilities:

- coordinate repositories
- enforce domain rules
- normalize or dedupe inputs
- manage commits/refreshes where needed
- produce schema-ready outputs

Do put here:

- domain logic
- aggregate updates
- dedupe rules
- default profile orchestration

Do not put here:

- HTTP exception classes
- route decorators

## `tests/`

Purpose:

- backend verification

Current shape:

- most tests use SQLite fixtures from `tests/conftest.py`
- one live Postgres smoke test uses `tests/test_postgres_integration.py`

Use this layer to:

- verify route behavior
- verify service behavior
- smoke test live Postgres bootstrap compatibility

## Worked Example: Where To Change Rule Creation

If you need to change how rules are created:

1. request/response shape: `schemas/rules.py`
2. route behavior: `api/routes/rules.py`
3. business rules: `services/rules_service.py`
4. persistence details: `repositories/rule_repository.py`
5. table/constraint shape: `models/rule.py`
6. SQL bootstrap alignment: top-level `database/initdb/10-schema.sql`

That last point is important: model changes often require matching SQL bootstrap changes outside `backend/`.

## Common Placement Rules

If a change is about:

- HTTP path, status codes, FastAPI dependencies: `api/`
- domain rules or orchestration: `services/`
- repeated DB access: `repositories/`
- table shape: `models/`
- payload shape: `schemas/`
- environment/runtime defaults: `core/`
- app startup or router registration: `app/`

When in doubt, start in the service layer and work outward from there.

## Related Pages

- [Architecture](architecture.md)
- [API surface](api.md)
- [Data model](data-model.md)
