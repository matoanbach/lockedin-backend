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

The backend owns versioned schema transitions through Alembic.

The top-level `database/` folder owns the matching fresh-database snapshot:

- Docker Postgres startup for local development
- SQL schema bootstrap
- seed data

Schema changes must stay aligned between:

- `backend/src/lockedin_backend/models/`
- `backend/migrations/`
- `database/initdb/10-schema.sql`

## Application Startup

File:

- `src/lockedin_backend/app/main.py`

Key behaviors:

- `create_app()` builds the FastAPI application
- the API router is mounted under `/api/v1`
- a root `/` endpoint returns a simple service message
- startup does not create or select a profile
- protected route groups require a `CurrentPrincipal` before service execution

## Request Lifecycle

Typical request flow:

1. FastAPI receives an HTTP request.
2. A route function in `api/routes/*.py` validates the request payload using a schema.
3. A protected route resolves a trusted `CurrentPrincipal`; the default dependency returns `401`.
4. The route gets a DB session via `Depends(get_db)` and passes `principal.profile_id` to a service.
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
3. The protected router resolves the trusted principal before the service runs.
4. `RulesService` canonicalizes the app ID and checks for duplicate rules.
5. `RuleRepository.create()` inserts a `Rule` ORM object.
6. The service commits and refreshes it.
7. The response is returned as `RuleResponse`.

## Current Identity Model

Phase B supplies the tenant foundation, not a working login system:

- `Account` owns exactly one non-demo `Profile` initially;
- `ExternalIdentity` links by exact immutable `(issuer, subject)`;
- `CurrentPrincipal` carries trusted account/profile/provider identifiers;
- the default principal dependency fails closed until Phase C installs Keycloak introspection;
- protected services accept an explicit trusted profile ID and never call
  `ensure_default_profile()`;
- the fixed `default` profile is demo-only and cannot be owned.

## Authentication Architecture Gate

Authentication is now the next planned architecture initiative, but it is not implemented. The
[Authentication, Session, and Tenant-Isolation ADR](decisions/authentication-session-tenant-isolation.md)
contains the evidence baseline, endpoint/data inventory, threat model, account/profile alternatives,
mobile queue lifecycle, tenant-enforcement design, acceptance matrix, and migration/rollback plan.

The ADR is **accepted for local implementation**, and its Phase B foundation is implemented. D1–D6 approve local/demo-only exposure,
self-hosted Keycloak OIDC with no external identity-service charge, verification/recovery, direct
Keycloak-token sessions with server-side revocation checks, physical-phone local TLS,
existing/pre-login data handling, and role-based operational ownership. The runtime still has no
real token authentication and remains suitable only for a trusted local/demo deployment until the
remaining controls are implemented and tested. Acting role holders,
contacts, access, and runbooks still require verification before release or external exposure.

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

These are not implemented in the current active architecture:

- Keycloak introspection/session authentication (Phase B tenant isolation foundation exists)
- Supabase integration
- microservices
- a complete identity/security audit workflow beyond the Phase B migration head

## Related Pages

- [Layers](layers.md)
- [Configuration](configuration.md)
- [Data model](data-model.md)
- [Deployment](deployment.md)
