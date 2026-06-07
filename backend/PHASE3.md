# Phase 3: Usage And Analytics

## Priority

Phase 3 is the next major product phase after persistent preferences, rules, and accountability contacts are in place.

This phase remains high priority because it replaces the largest remaining mock-driven part of the app with real backend data.

## Objective

Build the first real usage ingestion and analytics layer for LockdIn.

By the end of Phase 3:
- usage data should be accepted and persisted by the backend
- daily app aggregate data should be available for analytics queries
- daily category aggregate data should be available for analytics queries
- dashboard analytics should come from the database
- trends analytics should come from the database
- weekly summary analytics should come from the database
- the codebase should be ready for later feedback, enforcement, and notification work

## Scope

Included in Phase 3:
- usage ingestion endpoint
- usage event persistence model
- daily app aggregate persistence model
- daily category aggregate persistence model
- ingestion service logic
- analytics service logic
- dashboard analytics endpoint
- trends analytics endpoint
- weekly summary analytics endpoint
- migrations for Phase 3 tables
- tests for ingestion, aggregation, and analytics responses

Not included in Phase 3:
- OS-native usage collection implementation on Android or iOS
- app blocking enforcement
- notification delivery
- authentication
- Supabase integration
- push, SMS, or email provider work
- scheduled jobs
- advanced ML-style recommendations
- location analytics
- frontend analytics integration implementation itself

## Phase Direction

This phase is still backend-first.

Important context:
- Phase 2 already made preferences, rules, and accountability contacts persistent
- the frontend now persists those modules through the backend
- the dashboard, trends, and weekly summary screens are still powered by mock data
- the current repo does not yet include real OS-level device usage capture

That means Phase 3 should focus on:
- making the backend ready to receive usage data
- computing backend-owned aggregates and insights
- exposing stable analytics contracts that the frontend can adopt next

Implementation direction:
- Python backend
- FastAPI monolith
- SQLite for local development
- SQLAlchemy models and Alembic migrations
- no auth yet
- one implicit development profile still scopes data internally
- Android is the first real usage source the backend should be designed around

## Design Approach

Phase 3 should use both raw usage rows and backend-maintained aggregate rows.

Recommended approach:
- ingest session-like usage events into a `usage_events` table
- update or derive daily aggregate rows from those events
- use aggregates for most dashboard and weekly analytics queries

Why this approach:
- raw events preserve a source of truth for later refinement
- aggregates keep analytics queries simple and fast
- the backend stays flexible if the ingestion payload evolves later

For Android, Phase 3 should prefer reconstructed app sessions over already summarized daily totals.

The backend should not rely on a single `minutes + occurredAt` shape for analytics.

Instead, use a normalized event shape such as:
- app identifier
- app display name
- source event identifier
- optional category
- session start timestamp
- session end timestamp
- duration minutes
- device timezone

Why this recommendation:
- Android usage events can be reconstructed into foreground usage sessions
- session-like rows can be split correctly across hour buckets
- session-like rows can be split correctly across local day boundaries
- trends analytics become much more accurate than with single-point usage entries

## Android Data Source Direction

Phase 3 should assume Android as the first real usage source.

Recommended mobile-side behavior:
- use Android usage stats or usage events to reconstruct foreground app sessions
- send those reconstructed sessions to the backend
- keep the backend ingestion contract stable even if the Android collection logic evolves

Important note:
- Phase 3 does not require implementing the Android bridge yet
- but the backend contract should be shaped for that Android reality now

## Ownership Model

Auth is still deferred.

Phase 3 continues using the Phase 2 ownership model:
- a single implicit development profile
- all usage and analytics data is scoped to that default profile internally
- route shapes should stay future-compatible with authenticated ownership

Implementation note:
- all new Phase 3 tables should include `profile_id`
- services should resolve the default development profile through the existing profile context logic

## Idempotency And Time Boundaries

Phase 3 should treat ingestion as idempotent.

Required direction:
- every ingested event should include a stable client-provided `sourceEventId`
- repeated submission of the same event for the same profile must not double-count usage

Phase 3 should also make time boundaries explicit.

Required direction:
- store session timestamps in UTC
- store the device timezone as an IANA timezone string when possible
- derive `usage_date`, "today", and weekly windows using the local timezone rather than blindly in UTC

Why this matters:
- retries are common on mobile clients
- Android usage sessions often cross hour or day boundaries
- analytics like "today", "this week", and hourly trends are wrong if timezone handling is implicit

## Deliverables

Phase 3 is complete when the project has:
- persistent usage ingestion support
- daily app aggregate rows for analytics-ready summaries
- daily category aggregate rows for analytics-ready summaries
- a `POST /api/v1/usage/events` endpoint
- a `GET /api/v1/analytics/dashboard` endpoint
- a `GET /api/v1/analytics/trends` endpoint
- a `GET /api/v1/analytics/weekly-summary` endpoint
- tests covering ingestion, validation, idempotency, and analytics response behavior
- a clear frontend handoff plan for replacing mocked dashboard and trends providers

## Planned Modules

### 1. Usage Ingestion Module

Purpose:
- accept usage data from mobile or development tooling

What it should support now:
- ingest one or more session-like usage events for the default profile
- validate required fields and positive durations
- normalize app and category data
- persist raw rows for later analytics and auditing
- prevent duplicate ingestion when the client retries the same data

Suggested first endpoint:
- `POST /api/v1/usage/events`

Expected result:
- the backend can begin building real analytics without waiting on a full enforcement system

Implementation note:
- every ingested event should include a stable client-provided `sourceEventId`
- Phase 3 should treat ingestion as idempotent for repeated client retries

### 2. Daily Aggregation Module

Purpose:
- store analytics-friendly daily summary rows

What it should support now:
- accumulate total minutes by app and by day
- accumulate total minutes by category and by day
- retain app display name for stable analytics output
- support simple weekly and dashboard queries without scanning every raw event repeatedly

Expected result:
- analytics endpoints can answer common queries with simple aggregate reads

### 3. Dashboard Analytics Module

Purpose:
- support the current dashboard screen with real backend data

What it should return now:
- total minutes for today
- category breakdown for today
- weekly usage series for the last 7 days
- a simple day-over-day delta or comparison value

Suggested endpoint:
- `GET /api/v1/analytics/dashboard`

Expected result:
- the current dashboard screen can replace its hardcoded usage providers later

### 4. Trends Analytics Module

Purpose:
- support the trends screen with real backend data

What it should return now:
- usage by time of day
- daily totals for the current week or recent 7-day range
- top apps or categories
- a simple peak usage window insight

Suggested endpoint:
- `GET /api/v1/analytics/trends`

Expected result:
- the current trends screen can stop relying on static chart data later

Implementation note:
- hourly trends should be computed from raw `usage_events`
- daily app and category aggregates should remain the main source for dashboard and weekly summary reads

### 5. Weekly Summary Analytics Module

Purpose:
- support the weekly summary screen with real backend data

What it should return now:
- total usage this week
- average daily usage this week
- comparison vs last week
- number of days meeting the default daily limit goal
- a simple streak metric

Suggested endpoint:
- `GET /api/v1/analytics/weekly-summary`

Expected result:
- the weekly summary screen can replace its placeholder stats with backend values later

## Proposed Tables

### `usage_events`

Purpose:
- store raw session-like usage entries submitted to the backend

Suggested fields:
- `id`
- `profile_id`
- `app_id`
- `app_name`
- `category`
- `source_event_id`
- `started_at`
- `ended_at`
- `duration_minutes`
- `timezone`
- `created_at`
- `updated_at`

Suggested notes:
- `source_event_id` should be required and unique per profile
- `started_at` should be required
- `ended_at` should be required
- `duration_minutes` should be positive and derived by the backend from `started_at` and `ended_at`
- `timezone` should be required and use an IANA timezone string where possible
- `category` can be optional in the first iteration
- `app_id` remains the canonical identifier

Suggested constraints:
- unique on `profile_id + source_event_id`

### `usage_daily_app_aggregates`

Purpose:
- store precomputed daily totals by app for efficient analytics reads

Suggested fields:
- `id`
- `profile_id`
- `usage_date`
- `app_id`
- `app_name`
- `total_minutes`
- `created_at`
- `updated_at`

Suggested constraints:
- unique on `profile_id + usage_date + app_id`

Suggested notes:
- this table can be maintained during ingestion in the Phase 3 MVP
- `usage_date` should be derived in the event's local timezone, not blindly in UTC

### `usage_daily_category_aggregates`

Purpose:
- store precomputed daily totals by category for efficient dashboard and weekly reads

Suggested fields:
- `id`
- `profile_id`
- `usage_date`
- `category`
- `total_minutes`
- `created_at`
- `updated_at`

Suggested constraints:
- unique on `profile_id + usage_date + category`

## Suggested Request And Response Schemas

### Usage Ingestion Request Direction

The first ingestion payload should be explicit, idempotent, and Android-friendly.

The backend should derive `duration_minutes` from `startedAt` and `endedAt` rather than trusting a separate client-provided duration field.

Suggested shape:

```json
{
  "events": [
    {
      "sourceEventId": "android:com.instagram.android:1717795800:1717797600",
      "appId": "com.instagram.android",
      "appName": "Instagram",
      "category": "Social",
      "startedAt": "2026-06-07T20:30:00Z",
      "endedAt": "2026-06-07T21:00:00Z",
      "timezone": "Asia/Ho_Chi_Minh"
    }
  ]
}
```

Why this shape:
- easy to seed manually during development
- easy to generate later from Android session reconstruction
- supports retry-safe idempotent ingestion
- supports hour and day splitting for trends analytics

### Dashboard Response Example

```json
{
  "todayTotalMinutes": 280,
  "categoryBreakdown": [
    { "name": "Social", "minutes": 125 },
    { "name": "Entertainment", "minutes": 85 },
    { "name": "Productivity", "minutes": 42 },
    { "name": "Other", "minutes": 28 }
  ],
  "weeklyUsageHours": [3.2, 4.5, 2.8, 5.1, 4.2, 6.3, 5.8],
  "deltaFromYesterdayPercent": -12
}
```

### Trends Response Example

```json
{
  "hourlyUsage": [
    { "hour": "6am", "minutes": 5 },
    { "hour": "9am", "minutes": 15 },
    { "hour": "12pm", "minutes": 35 }
  ],
  "weeklyUsage": [
    { "day": "Mon", "hours": 3.2 },
    { "day": "Tue", "hours": 4.5 },
    { "day": "Wed", "hours": 2.8 }
  ],
  "peakUsageWindow": "9 PM - 11 PM"
}
```

### Weekly Summary Response Example

```json
{
  "screenTimeReductionPercent": 26,
  "totalWeekHours": 18,
  "dailyAverageHours": 2.6,
  "goalsMetDays": 4,
  "longestStreakDays": 12
}
```

## Analytics Contract Direction

General principles:
- use `/api/v1`
- return stable JSON
- use camelCase responses for frontend compatibility
- keep derived analytics fields explicit rather than embedding heavy UI formatting in the backend
- return valid empty states when no usage data exists

Important Phase 3 behavior decision:
- analytics endpoints should not fail when there is no data
- instead, they should return zero-like summaries and empty collections where appropriate

Important time boundary decision:
- the backend should store session timestamps in UTC
- the backend should derive `usage_date`, "today", and weekly windows using the event or profile timezone
- Phase 3 should not treat UTC day boundaries as the product definition of a user's day

Important weekly summary decision:
- `goalsMetDays` should mean `total daily usage <= default_daily_limit_minutes`
- this keeps the metric explicit and compatible with the existing preferences model

That makes frontend integration much simpler and avoids special-case error handling for empty local development databases.

## Step-By-Step Implementation Plan

### Step 1: Add Usage Models

Tasks:
- create `usage_event.py`
- create `usage_daily_app_aggregate.py`
- create `usage_daily_category_aggregate.py`
- register all three in `models/__init__.py`
- keep model fields consistent with Phase 2 naming and timestamp mixins

Output:
- ORM models exist for raw events and daily aggregate rows

### Step 2: Add Migration

Tasks:
- create a new Alembic revision for Phase 3 usage tables
- add indexes and uniqueness constraints needed for aggregate updates and idempotent event ingestion
- verify migration upgrades cleanly on a fresh local database

Output:
- schema supports usage ingestion and analytics reads

### Step 3: Add Schemas

Tasks:
- create request schemas for usage ingestion
- create response schemas for dashboard analytics
- create response schemas for trends analytics
- create response schemas for weekly summary analytics
- define timezone-aware date window inputs or internal service assumptions clearly

Output:
- API contracts are defined independently of ORM models

### Step 4: Add Repositories

Tasks:
- add usage event repository methods for create and list/query support
- add app aggregate repository methods for upsert-like updates and read queries
- add category aggregate repository methods for upsert-like updates and read queries
- keep repositories thin and focused on data access

Output:
- services have stable database helpers for ingestion and analytics

### Step 5: Add Usage Service

Tasks:
- accept a usage ingestion payload
- resolve the default development profile
- reject or skip duplicate `sourceEventId` rows for the same profile
- validate and persist usage rows
- split sessions correctly when they cross local day boundaries if needed
- update app and category aggregate rows for affected local dates
- commit as one coherent ingestion operation

Output:
- the backend can persist incoming usage data safely

### Step 6: Add Analytics Service

Tasks:
- implement dashboard analytics queries
- implement trends analytics queries
- implement weekly summary analytics queries
- define consistent zero-data behavior
- define timezone-aware date window calculations
- define a simple "goal met" calculation using the default daily limit preference

Output:
- all Phase 3 analytics responses are produced from backend-owned data

### Step 7: Add Routes

Tasks:
- add `api/routes/usage.py`
- add `api/routes/analytics.py`
- register both in the shared API router
- keep route behavior consistent with existing error handling patterns

Output:
- Phase 3 endpoints are publicly available under `/api/v1`

### Step 8: Add Tests

Tasks:
- add route tests for usage ingestion
- add route tests for dashboard analytics
- add route tests for trends analytics
- add route tests for weekly summary analytics
- add a duplicate `sourceEventId` ingestion test to prove idempotency
- add a timezone-boundary aggregation test to prove local-day correctness
- add service tests for aggregation behavior if the logic becomes non-trivial

Output:
- ingestion and analytics logic are protected by automated tests

## Suggested File Targets

Likely new or updated files:

```text
backend/src/lockedin_backend/api/routes/usage.py
backend/src/lockedin_backend/api/routes/analytics.py
backend/src/lockedin_backend/api/router.py
backend/src/lockedin_backend/models/usage_event.py
backend/src/lockedin_backend/models/usage_daily_app_aggregate.py
backend/src/lockedin_backend/models/usage_daily_category_aggregate.py
backend/src/lockedin_backend/models/__init__.py
backend/src/lockedin_backend/schemas/usage.py
backend/src/lockedin_backend/schemas/analytics.py
backend/src/lockedin_backend/repositories/usage_repository.py
backend/src/lockedin_backend/repositories/usage_daily_app_aggregate_repository.py
backend/src/lockedin_backend/repositories/usage_daily_category_aggregate_repository.py
backend/src/lockedin_backend/services/usage_service.py
backend/src/lockedin_backend/services/analytics_service.py
backend/alembic/versions/<phase3_revision>.py
backend/tests/test_usage.py
backend/tests/test_analytics.py
```

## Testing Plan

Minimum Phase 3 coverage should include:
- valid usage ingestion request persists rows
- invalid usage ingestion request returns `422`
- repeated ingestion of the same `sourceEventId` does not double-count data
- aggregate rows update correctly after ingestion
- local-day aggregation behaves correctly around timezone boundaries
- dashboard endpoint returns correct totals and category breakdowns
- trends endpoint returns correctly shaped hourly and weekly series
- weekly summary endpoint returns consistent week-over-week summary values
- empty-data analytics responses return valid zero/default payloads

Recommended testing emphasis:
1. ingestion validation
2. idempotent event handling
3. aggregate correctness
4. dashboard response correctness
5. trends response correctness
6. weekly summary response correctness

## Frontend Handoff

Phase 3 remains backend-first, but it should produce a clean handoff for frontend integration.

Primary frontend consumers after Phase 3 backend completion:
- `frontend/flutter_app/lib/features/dashboard/data/providers/dashboard_provider.dart`
- `frontend/flutter_app/lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `frontend/flutter_app/lib/features/trends/presentation/screens/trends_screen.dart`
- `frontend/flutter_app/lib/features/analytics/presentation/screens/analytics_summary_screen.dart`

Expected frontend handoff after backend completion:
- replace mocked dashboard providers with API-backed providers
- replace static trends chart data with analytics endpoint data
- replace placeholder weekly summary stats with backend data

Phase 3 does not require implementing that frontend work immediately, but it should make the contracts clear enough that the next phase can do so directly.

## Completion Criteria

Phase 3 is complete when:
- usage ingestion persists data to the database
- daily app aggregate rows exist and update correctly
- daily category aggregate rows exist and update correctly
- dashboard analytics returns real DB-backed values
- trends analytics returns real DB-backed values
- weekly summary analytics returns real DB-backed values
- analytics endpoints handle empty data safely
- tests cover the main success and validation paths
- the frontend has a clear backend contract for replacing mocked analytics providers

## Out Of Scope

The following should not block Phase 3 completion:
- Android usage access bridge implementation
- iOS screen-time integration
- rule enforcement or app lock execution
- notifications and delivery logs
- feedback submission endpoint
- auth and multi-user protection
- Supabase migration
- background job infrastructure
- advanced recommendation or coaching systems

## Open Questions

### 1. Should ingestion accept raw-ish entries or already summarized daily payloads?

Recommendation:
- accept session-like entries with `sourceEventId`, `startedAt`, and `endedAt`
- aggregate on the backend

Why:
- still simple for MVP
- more future-friendly than daily-only summary uploads
- better supports later trends analysis
- better matches Android session reconstruction

### 2. Should category be required from the client?

Recommendation:
- keep category optional in the first iteration
- allow the backend to default to `Other` when absent

Why:
- reduces coupling to early mobile-side categorization logic
- keeps ingestion easy to seed during development

### 3. Should aggregation happen synchronously during ingestion?

Recommendation:
- yes, in Phase 3

Why:
- local SQLite scale is small
- simpler than introducing jobs or async pipelines
- easiest to verify in tests and local development

### 4. How should a "goal met" day be defined in Phase 3?

Recommendation:
- define it as `total daily usage <= default_daily_limit_minutes`

Why:
- simple and explicit
- uses an existing persisted preference
- avoids depending on rule enforcement before that system exists
