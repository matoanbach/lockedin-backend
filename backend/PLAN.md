# Backend Plan

## Status

The backend is still in planning and early setup.

This document defines the current implementation plan for the LockdIn backend.

## Priority

Backend is the highest priority for the project right now.

Why:
- the frontend already exists as a Flutter prototype
- most frontend data is still mocked or stored only in memory
- the app needs real persistence and APIs before deeper frontend integration can happen
- the team has already decided to use a simpler backend architecture than the older microservice design in the docs

## Architecture Direction

We will build a simple backend first.

Current direction:
- Python backend
- one FastAPI service
- REST API only
- modular monolith structure
- Postgres initialized from the top-level `database/` folder
- authentication deferred to a later phase
- Supabase integration deferred to a later phase

Implementation assumptions:
- everything under `docs/` is historical reference only
- the frontend will not be modified first; backend is built first
- the current frontend is still mostly prototype and local-state driven

This intentionally replaces the earlier, more complex design involving:
- multiple microservices
- internal gRPC
- Kubernetes/EKS
- separate auth service

## Goals

The backend should provide the core application data layer for:
- rules
- usage ingestion
- analytics
- accountability contacts
- preferences
- future notifications
- future authentication integration

The backend should be designed so auth and Supabase can be added later without forcing a major rewrite.

## Core Principles

1. Keep the backend simple first.
2. Build around the current frontend and the project requirements.
3. Separate business logic cleanly inside one service.
4. Keep the database contract stable between backend code and the initialized Postgres schema.
5. Avoid premature infrastructure complexity.
6. Make each module testable in isolation.
7. Prefer backend-first progress without blocking on frontend integration.

## Planned Components

### 1. API Application Layer

What it is:
- the FastAPI app entrypoint and route registration layer

What it does:
- starts the application
- registers routers
- defines API versioning
- handles shared middleware and exception handling
- exposes a health check endpoint

Implementation plan:
- create the main FastAPI app
- add `/health`
- group endpoints under `/api/v1`
- organize routes by feature domain

Why it matters:
- this is the backbone of the backend and should be implemented first

### 2. Configuration Layer

What it is:
- shared application configuration and environment management

What it does:
- loads runtime settings
- stores database configuration
- stores environment mode
- reserves space for future auth and provider settings

Implementation plan:
- add a central settings module
- separate local, test, and future production settings
- keep configuration environment-driven

Why it matters:
- this keeps the project maintainable as the backend grows

### 3. Database Layer

What it is:
- the persistence layer for the application

What it does:
- manages database connection and sessions
- defines schema and models
- stores app data reliably

Implementation plan:
- connect to the initialized Postgres database from the top-level `database/` folder
- keep backend schema definitions aligned with the database bootstrap SQL
- use SQLAlchemy or SQLModel
- evolve schema through the SQL bootstrap files under `database/initdb/`

Why it matters:
- the database is the foundation for rules, analytics, and accountability

### 4. Domain Models

What they are:
- the core entities the backend stores and operates on

Initial planned models:
- `profiles`
- `preferences`
- `rules`
- `usage_events`
- `usage_daily_aggregates`
- `accountability_contacts`
- `weekly_feedback`
- `notification_logs` later

What they do:
- represent the business data of the system
- support the Flutter screens with real persisted state

Implementation plan:
- define schema based on current frontend needs and historical project docs where still useful
- include a future-friendly ownership field such as `user_id` even before auth exists
- keep the models small and extend them later as new features mature

Why it matters:
- good schema decisions now reduce rewrite risk later

### 5. Rules Module

What it is:
- backend support for lockdown rule storage and management

What it does:
- creates rules
- lists rules
- updates rules
- enables or disables rules
- deletes rules

Implementation plan:
- start with per-app rules only
- store:
  - app identifier
  - app name
  - daily limit
  - enabled state
- extend later for category rules, schedules, recurrence, and exceptions

Planned endpoints:
- `GET /api/v1/rules`
- `POST /api/v1/rules`
- `PATCH /api/v1/rules/{rule_id}`
- `DELETE /api/v1/rules/{rule_id}`

Why it matters:
- rules are central to the product and should be one of the first real backend features

### 6. Usage Ingestion Module

What it is:
- backend ingestion for usage data sent by the mobile client

What it does:
- accepts usage events or daily summaries
- validates payloads
- stores usage data
- updates aggregates

Implementation plan:
- begin simple
- support posting usage entries from the app
- allow the first version to accept either raw events or summary-style input depending on frontend readiness
- update daily aggregate rows during ingestion

Planned endpoints:
- `POST /api/v1/usage/events`

Why it matters:
- without usage ingestion, analytics cannot become real

### 7. Analytics Module

What it is:
- backend computation and retrieval layer for dashboard and trends data

What it does:
- returns daily totals
- returns weekly totals
- returns app or category breakdowns
- returns summary data for dashboard and trends screens

Implementation plan:
- begin with DB-backed summary endpoints
- rely on daily aggregates where possible
- keep advanced analytics for later phases

Planned endpoints:
- `GET /api/v1/analytics/dashboard`
- `GET /api/v1/analytics/trends`
- `GET /api/v1/analytics/weekly-summary`

Why it matters:
- the current frontend analytics and dashboard screens are still using mock data

### 8. Accountability Module

What it is:
- backend support for accountability contacts

What it does:
- stores accountability contacts
- lists contacts
- removes contacts
- prepares for future accountability reporting

Implementation plan:
- first phase stores contact data and consent metadata only
- actual email or SMS delivery comes later

Planned endpoints:
- `GET /api/v1/accountability/contacts`
- `POST /api/v1/accountability/contacts`
- `DELETE /api/v1/accountability/contacts/{contact_id}`

Why it matters:
- the frontend already has this screen, but it is currently local-only

### 9. Preferences Module

What it is:
- backend support for user settings and app preferences

What it does:
- stores onboarding completion state
- stores default daily limit
- stores tone preference
- stores accessibility-related preferences
- stores future privacy settings

Implementation plan:
- support only the preferences already implied by the frontend
- keep the payload small and easy to extend later

Planned endpoints:
- `GET /api/v1/me/preferences`
- `PUT /api/v1/me/preferences`

Why it matters:
- this gives the frontend a real persistence layer without waiting for every advanced feature

### 10. Feedback Module

What it is:
- backend support for weekly feedback and summary rating submission

What it does:
- accepts rating and comment submissions
- stores feedback for later reporting or analysis

Implementation plan:
- keep it small and standalone

Planned endpoints:
- `POST /api/v1/analytics/feedback`

Why it matters:
- the frontend already exposes a weekly summary and feedback flow

### 11. Notification Module

What it is:
- future backend logic for notification formatting and delivery

What it does:
- formats tone-based notification messages
- sends push, email, or SMS in later phases
- logs delivery attempts

Implementation status:
- deferred

Plan:
- design the data model early
- do not build provider integrations in the first milestone
- add dispatch later when auth, identity, and usage enforcement are more mature

Why it matters:
- important feature, but not required for the first usable backend

### 12. Authentication Module

What it is:
- future login, token issuance, and route protection layer

What it does:
- registers and logs in users
- issues and validates tokens
- protects API routes
- links data ownership to authenticated users

Implementation status:
- deferred to a later phase

Plan:
- reserve space in the architecture for auth routes, auth dependencies, and ownership checks
- keep domain tables structured around future identity linkage
- avoid endpoint designs that would be hard to secure later

Why it matters:
- auth is important, but it should not block the first backend milestone

### 13. Supabase Integration

What it is:
- future external platform for managed Postgres and possible auth support

What it does:
- could provide managed database hosting later
- could provide auth support later
- could simplify hosted operations later

Implementation status:
- deferred to a later phase

Plan:
- do not tightly couple current business logic to Supabase-specific APIs
- keep the backend portable
- revisit integration once the core API and schema are stable

Why it matters:
- we want the option to adopt Supabase later without rewriting core logic

## Recommended Structure

Proposed structure:
- `backend/pyproject.toml`
- `backend/Makefile`
- `backend/scripts/`
- `backend/src/lockedin_backend/app/`
- `backend/src/lockedin_backend/api/`
- `backend/src/lockedin_backend/api/routes/`
- `backend/src/lockedin_backend/core/`
- `backend/src/lockedin_backend/db/`
- `backend/src/lockedin_backend/models/`
- `backend/src/lockedin_backend/schemas/`
- `backend/src/lockedin_backend/services/`
- `backend/src/lockedin_backend/repositories/`
- `backend/tests/`

Responsibilities:
- `api/routes`: FastAPI route definitions
- `core`: config and shared utilities
- `db`: engine, session, and migrations
- `models`: ORM models
- `schemas`: request and response schemas
- `services`: business logic
- `repositories`: data access helpers
- `tests`: unit and integration tests

## Implementation Priorities

### Phase 1: Backend Foundation

Highest priority.

Build:
- FastAPI app skeleton
- config and settings
- database connection
- migration setup
- base models
- health endpoint

Deliverable:
- backend service starts successfully
- database connection works
- migrations work locally

### Phase 2: Core Product Data

High priority.

Build:
- rules module
- preferences module
- accountability module

Deliverable:
- backend exposes persisted APIs that can later replace local-only frontend state for these screens

### Phase 3: Usage And Analytics

High priority.

Build:
- usage ingestion endpoint
- daily aggregation logic
- dashboard, trends, and weekly summary endpoints

Deliverable:
- frontend dashboard and analytics screens can consume real backend data

### Phase 4: Feedback And Supporting Features

Medium priority.

Build:
- weekly feedback endpoint
- analytics refinements
- better validation and error handling

Deliverable:
- backend supports more of the current frontend behavior

### Phase 5: Auth And Supabase

Later phase.

Build:
- auth routes
- token validation
- protected routes
- ownership enforcement
- optional Supabase integration

Deliverable:
- backend becomes multi-user and secured

## Out Of Scope For The Initial Backend Milestone

The following should not block the first backend implementation:
- Supabase auth integration
- JWT route protection
- email verification
- password reset
- push notification providers
- SMS or email sending
- Kubernetes/EKS deployment
- gRPC
- complex background jobs
- advanced location analytics
- data export and deletion workflows

## API Design Notes

General principles:
- use REST
- use `/api/v1`
- return stable JSON payloads
- validate inputs carefully
- keep schemas frontend-friendly
- include future ownership fields internally even if auth is deferred

## Testing Expectations

The backend should include tests from the start.

Minimum:
- unit tests for services
- route tests for core endpoints
- database-backed integration tests for rules and usage flows

Priority order:
1. rules tests
2. analytics tests
3. accountability tests
4. preferences tests

## Success Criteria

The initial backend is successful when:
- the service boots locally
- migrations run successfully
- rules can be created, read, updated, and deleted
- preferences persist correctly
- accountability contacts persist correctly
- usage data can be ingested
- analytics endpoints return real database-backed values
- the frontend has a clear later path to replace mock providers with API calls

## Summary

This backend will be implemented as a simple FastAPI monolith first.

Highest priority order:
1. backend foundation
2. profile-scoped persistence
3. preferences
4. rules
5. accountability
6. usage ingestion
7. analytics
8. feedback

Deferred until later:
- auth
- Supabase integration
- notification infrastructure
- more complex deployment architecture
