# Data Model

This page explains the current persisted backend entities and the most important constraints behind them.

## Source Of Truth Rule

For local schema bootstrap, the source of truth is the top-level `database/` folder.

Important files:

- `database/initdb/10-schema.sql`
- `database/initdb/20-seed.sql`

The backend ORM models under `backend/src/lockedin_backend/models/` must stay aligned with that schema.

Alembic is not part of the active workflow.

## Current Entity Set

Current SQLAlchemy models are exported from:

- `src/lockedin_backend/models/__init__.py`

Main entities:

- `Profile`
- `Preferences`
- `Rule`
- `UsageEvent`
- `UsageDailyAppAggregate`
- `UsageDailyCategoryAggregate`
- `AccountabilityContact`
- `EnforcementEvent`

## Profile

File:

- `models/profile.py`

Purpose:

- current logical owner for almost all user-scoped data

Important details:

- unique `slug`
- current default profile slug is `default`
- related to preferences, rules, contacts, usage events, aggregates, and enforcement events

## Preferences

File:

- `models/preferences.py`

Purpose:

- store user-level configuration for the current profile

Important details:

- one preferences row per profile
- stores onboarding completion, daily limit, notification tone, and display/accessibility settings

Current defaults come from `core/constants.py`, including:

- default daily limit: `180`
- default notification tone: `professional`
- default text size percent: `100`

## Rules

File:

- `models/rule.py`

Purpose:

- per-app usage limit rules

Important details:

- unique by `(profile_id, app_id)`
- stores `app_id`, `app_name`, `limit_minutes`, `enabled`

Service behavior:

- `RulesService` canonicalizes app IDs before create checks
- duplicate logical app rules raise a conflict

## Accountability Contacts

File:

- `models/accountability_contact.py`

Purpose:

- contact records tied to the current profile

Important details:

- unique by `(profile_id, email)`
- stores name, email, and consent flag

## Usage Events

File:

- `models/usage_event.py`

Purpose:

- raw client-submitted usage sessions

Important details:

- unique by `(profile_id, source_event_id)`
- indexed by `(profile_id, started_at)`
- stores `started_at`, `ended_at`, `duration_minutes`, and timezone

Service behavior:

- `UsageService` dedupes by `source_event_id`
- events are normalized to UTC for storage

## Daily Aggregates

Files:

- `models/usage_daily_app_aggregate.py`
- `models/usage_daily_category_aggregate.py`

Purpose:

- precomputed day-level totals used by analytics

Important details:

- app aggregate unique by `(profile_id, usage_date, app_id)`
- category aggregate unique by `(profile_id, usage_date, category)`
- both have profile/date indexes

Service behavior:

- `UsageService` updates these during usage ingestion
- event time is split by local date before minutes are applied

## Enforcement Events

File:

- `models/enforcement_event.py`

Purpose:

- store warnings and intervention-related events

Important details:

- may reference a `rule_id`
- stores `event_type`, `usage_date`, `used_minutes`, `limit_minutes`
- metadata is stored in `metadata_json`

Examples of event types appear in `schemas/enforcement.py`.

## Current Single-Profile Assumption

The app currently behaves as a single-profile system for real usage.

That behavior comes from `services/profile_context.py`, which:

- ensures a default profile exists
- ensures matching preferences exist
- commits them during startup or first use when necessary

New teammates should treat this as a deliberate temporary design, not a full auth model.

## Important Backend/Data Boundary

If you change:

- model columns
- unique constraints
- indexes
- enum-like value assumptions

you usually also need to update the SQL bootstrap under the top-level `database/` folder.

## Related Pages

- [Architecture](architecture.md)
- [Layers](layers.md)
- [API surface](api.md)
