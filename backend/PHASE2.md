# Phase 2: Core Product Data

## Priority

Phase 2 is the first feature phase after the backend foundation.

This phase remains high priority because it creates the first real product APIs the app will depend on later.

## Objective

Build the first backend-backed product modules without introducing authentication yet.

By the end of Phase 2:
- rules should persist in the database
- preferences should persist in the database
- accountability contacts should persist in the database
- the backend should expose stable REST endpoints for these modules
- the codebase should be ready for Phase 3 usage ingestion and analytics work

## Scope

Included in Phase 2:
- rules module
- preferences module
- accountability contacts module
- database models and migrations for those modules
- request and response schemas
- service and repository logic
- tests for the new endpoints and business logic

Not included in Phase 2:
- authentication
- Supabase integration
- usage ingestion
- analytics endpoints
- notification delivery
- scheduled jobs
- frontend changes

## Phase Direction

This phase is still backend-first.

Important constraints:
- do not modify the frontend yet
- do not add auth yet
- do not treat historical docs under `docs/` as current implementation requirements

Current implementation direction:
- Python backend
- FastAPI monolith
- SQLite for local development
- no auth yet
- no frontend integration yet

## Temporary Ownership Model

Because auth is deferred, Phase 2 needs a temporary way to scope data.

For this phase, use a **single implicit development profile**.

What that means:
- the backend behaves as if one default profile exists
- feature endpoints operate against that default profile internally
- no user login, token, or external identity is required

Why this approach:
- it avoids blocking backend feature development on auth
- it avoids frontend changes during this phase
- it keeps the API simple for local development and testing
- it can later be replaced with authenticated ownership in Phase 5

Implementation note:
- keep internal schema future-friendly by including a `profile_id` or `user_id` foreign key pattern now
- the default development profile can be seeded automatically or created lazily at startup

## Deliverables

Phase 2 is complete when the project has:
- persistent rules CRUD endpoints
- persistent preferences read and update endpoints
- persistent accountability contact create, list, and delete endpoints
- migrations for all Phase 2 tables
- tests covering the main success and validation paths
- a clear handoff point for Phase 3 analytics and usage work

## Planned Modules

### 1. Profile Context Module

Purpose:
- provide a temporary internal ownership context while auth is deferred

What it does:
- resolves or creates the single default development profile
- gives services a consistent profile context for reads and writes

Implementation:
- create a lightweight internal helper or service
- avoid exposing auth-like semantics publicly
- keep the logic easy to replace later when real auth exists

Expected result:
- all Phase 2 data is consistently tied to the same default profile

### 2. Preferences Module

Purpose:
- persist the app settings currently stored only in memory on the frontend

What it should support now:
- onboarding completion state
- default daily limit
- notification tone
- accessibility settings

Suggested fields:
- `profile_id`
- `has_completed_onboarding`
- `default_daily_limit_minutes`
- `notification_tone`
- `text_size_percent`
- `high_contrast`
- `large_tap_targets`
- `created_at`
- `updated_at`

Planned endpoints:
- `GET /api/v1/me/preferences`
- `PUT /api/v1/me/preferences`

Route note:
- the `/me/...` shape is kept for future auth compatibility even though it resolves to the implicit development profile in this phase

Expected result:
- backend can replace the current local-only onboarding and settings state later

### 3. Rules Module

Purpose:
- persist and manage lockdown rules

What it should support now:
- per-app rules only
- enable and disable
- update limit
- delete rule

Suggested fields:
- `id`
- `profile_id`
- `app_id`
- `app_name`
- `limit_minutes`
- `enabled`
- `created_at`
- `updated_at`

Important note:
- the current frontend model only has `appName`, `limitMinutes`, and UI fields like `icon` and `color`
- backend should treat `app_id` as the canonical identifier and `app_name` as display data
- UI-only fields should stay out of the backend model

Planned endpoints:
- `GET /api/v1/rules`
- `POST /api/v1/rules`
- `PATCH /api/v1/rules/{rule_id}`
- `DELETE /api/v1/rules/{rule_id}`

Expected result:
- backend has a real persisted rules data model ready for later enforcement and analytics

### 4. Accountability Contacts Module

Purpose:
- persist accountability contact data without sending notifications yet

What it should support now:
- add contact
- list contacts
- delete contact

Suggested fields:
- `id`
- `profile_id`
- `name`
- `email`
- `consent_confirmed`
- `created_at`
- `updated_at`

Implementation note:
- delivery is out of scope in this phase
- keep contact storage minimal and future-ready

Planned endpoints:
- `GET /api/v1/accountability/contacts`
- `POST /api/v1/accountability/contacts`
- `DELETE /api/v1/accountability/contacts/{contact_id}`

Expected result:
- backend can replace the current local-only accountability partner list later

## Proposed Tables

### `profiles`

Purpose:
- temporary ownership root for the no-auth phase

Suggested fields:
- `id`
- `slug` or `name`
- `created_at`
- `updated_at`

Notes:
- only one default row is needed for now
- keep the structure compatible with future authenticated ownership

### `preferences`

Purpose:
- store app-level settings for the default profile

Suggested constraints:
- one-to-one with `profiles`

### `rules`

Purpose:
- store per-app time limits

Suggested constraints:
- many rules belong to one profile
- `app_id` should be required

### `accountability_contacts`

Purpose:
- store opted-in accountability contacts

Suggested constraints:
- many contacts belong to one profile
- email should be validated and normalized

## API Contract Direction

General principles:
- use `/api/v1`
- return stable JSON
- validate input carefully
- avoid frontend-specific presentation fields where possible
- keep responses simple enough for the current Flutter app to adopt later
- keep route shapes future-compatible with authenticated ownership

### Preferences Response Example

```json
{
  "hasCompletedOnboarding": false,
  "defaultDailyLimitMinutes": 180,
  "notificationTone": "professional",
  "accessibility": {
    "textSizePercent": 100,
    "highContrast": false,
    "largeTapTargets": false
  }
}
```

### Rule Response Example

```json
{
  "id": "rule_123",
  "appId": "com.instagram.android",
  "appName": "Instagram",
  "limitMinutes": 120,
  "enabled": true
}
```

### Accountability Contact Response Example

```json
{
  "id": "contact_123",
  "name": "John Doe",
  "email": "john@example.com",
  "consentConfirmed": false
}
```

## Step-By-Step Implementation Plan

### Step 1: Add Phase 2 Models

Tasks:
- add `profiles` model
- add `preferences` model
- add `rules` model
- add `accountability_contacts` model
- register model metadata

Output:
- Phase 2 domain models exist in the backend

### Step 2: Add Migrations

Tasks:
- generate migration for Phase 2 tables
- apply migration locally
- verify schema creation against SQLite

Output:
- Phase 2 schema is persisted and versioned

### Step 3: Add Default Profile Resolution

Tasks:
- implement helper or service for resolving the implicit development profile
- ensure all Phase 2 services use the same profile context

Output:
- all Phase 2 data reads and writes are consistently scoped

### Step 4: Implement Preferences Module

Tasks:
- create schemas for read and update
- add repository and service logic
- add API routes
- define validation rules and defaults

Output:
- preferences can be retrieved and updated through the API

### Step 5: Implement Rules Module

Tasks:
- create schemas for create, list, update, and delete
- add repository and service logic
- add API routes
- validate required fields such as `app_id`, `app_name`, and `limit_minutes`

Output:
- rules CRUD works against the database

### Step 6: Implement Accountability Contacts Module

Tasks:
- create schemas for create, list, and delete
- add repository and service logic
- add API routes
- validate and normalize email values

Output:
- accountability contacts persist correctly

### Step 7: Add Tests

Tasks:
- add route tests for all new endpoints
- add service tests for validation and data behavior
- add tests for default profile resolution

Output:
- Phase 2 behavior is covered by automated tests

## Validation Rules

### Preferences
- `default_daily_limit_minutes` must be positive
- `notification_tone` must be one of: `fun`, `edgy`, `professional`
- `text_size_percent` should stay within a defined range

### Rules
- `app_id` is required
- `app_name` is required
- `limit_minutes` must be positive
- duplicate app rules should either be prevented or updated intentionally

### Accountability Contacts
- `email` is required
- email must be valid
- duplicate contacts for the same profile should be prevented

## Acceptance Criteria

Phase 2 is done when all of the following are true:
- preferences persist correctly in the database
- rules can be created, listed, updated, and deleted
- accountability contacts can be created, listed, and deleted
- all Phase 2 endpoints operate using the implicit development profile
- migrations succeed locally on SQLite
- tests pass for the main endpoint flows and validation cases
- the backend is ready for Phase 3 usage ingestion and analytics work

## Risks And Notes

- frontend models are still prototype-oriented, so backend should not copy UI-only fields like icons or colors into persistence
- no frontend changes in this phase means some endpoint contracts are backend-driven first and will be integrated later
- historical documents may describe older architectures and should not override the current Python monolith plan
- the temporary implicit profile model is a development convenience and should not leak into the long-term auth design
- keep naming stable now so later frontend integration is straightforward

## Out Of Scope Reminder

Do not expand Phase 2 into:
- usage ingestion
- dashboard analytics
- trends analytics
- weekly summary analytics
- notifications delivery
- auth or JWTs
- Supabase integration

Those belong to later phases.

## Summary

Phase 2 creates the first real backend product modules.

Highest-priority outputs:
1. implicit development profile context
2. persistent preferences module
3. persistent rules module
4. persistent accountability contacts module
5. migrations and tests for all of the above

Once Phase 2 is complete, the backend will be ready for Phase 3 usage ingestion and analytics implementation.
