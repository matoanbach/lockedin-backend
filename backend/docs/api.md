# API Surface

This page is the human-oriented map of the current backend API.

Base path:

- `/api/v1`

App root path:

- `/`

Interactive API docs:

- Swagger UI: `/api/docs`
- ReDoc: `/api/redoc`
- OpenAPI JSON: `/openapi.json`

Static backend docs site:

- `/docs/`

## Root

File:

- `src/lockedin_backend/app/main.py`

Route:

- `GET /`

Purpose:

- simple service message proving the app is running

## Health

File:

- `src/lockedin_backend/api/routes/health.py`

Route:

- `GET /api/v1/health`

Purpose:

- lightweight liveness check

Current behavior:

- returns `status`, `service`, and `version`
- does not currently verify database connectivity

## Rules

File:

- `src/lockedin_backend/api/routes/rules.py`

Routes:

- `GET /api/v1/rules`
- `GET /api/v1/rules/status`
- `POST /api/v1/rules`
- `PATCH /api/v1/rules/{rule_id}`
- `DELETE /api/v1/rules/{rule_id}`

Related code:

- schemas: `schemas/rules.py`, `schemas/rule_status.py`
- services: `services/rules_service.py`, `services/rule_status_service.py`
- repository: `repositories/rule_repository.py`

## Usage

File:

- `src/lockedin_backend/api/routes/usage.py`

Route:

- `POST /api/v1/usage/events`

Purpose:

- ingest client usage events
- dedupe by `source_event_id`
- update daily aggregates

Related code:

- schemas: `schemas/usage.py`
- service: `services/usage_service.py`
- repositories: `repositories/usage_repository.py`, aggregate repositories

## Analytics

File:

- `src/lockedin_backend/api/routes/analytics.py`

Routes:

- `GET /api/v1/analytics/dashboard`
- `GET /api/v1/analytics/trends`
- `GET /api/v1/analytics/weekly-summary`

Purpose:

- serve dashboard and trends views
- serve weekly summary metrics

Related code:

- schemas: `schemas/analytics.py`
- service: `services/analytics_service.py`

## Enforcement

File:

- `src/lockedin_backend/api/routes/enforcement.py`

Route:

- `POST /api/v1/enforcement/events`

Purpose:

- persist enforcement and warning events linked to usage and rules

Related code:

- schema: `schemas/enforcement.py`
- service: `services/enforcement_service.py`
- repository: `repositories/enforcement_event_repository.py`

## Accountability

File:

- `src/lockedin_backend/api/routes/accountability.py`

Routes:

- `GET /api/v1/accountability/contacts`
- `POST /api/v1/accountability/contacts`
- `DELETE /api/v1/accountability/contacts/{contact_id}`

Related code:

- schema: `schemas/accountability.py`
- service: `services/accountability_service.py`
- repository: `repositories/accountability_repository.py`

## Preferences

File:

- `src/lockedin_backend/api/routes/preferences.py`

Routes:

- `GET /api/v1/me/preferences`
- `PUT /api/v1/me/preferences`

Purpose:

- fetch and update the current profile's preferences

Related code:

- schema: `schemas/preferences.py`
- service: `services/preferences_service.py`
- repository: `repositories/preferences_repository.py`

## Current API Characteristics

- no auth yet
- APIs currently operate against the default profile model
- request and response fields are exposed as camelCase through `APIModel`

## Where To Start When Changing An Endpoint

1. route module in `api/routes/`
2. request/response schema in `schemas/`
3. business logic in `services/`
4. persistence helpers in `repositories/`
5. ORM model shape in `models/`
6. if table shape changes, align top-level `database/initdb/10-schema.sql`

## Related Pages

- [Layers](layers.md)
- [Data model](data-model.md)
- [Testing](testing.md)
