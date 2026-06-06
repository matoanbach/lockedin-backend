# Phase 1: Backend Foundation

## Priority

Phase 1 is the highest-priority implementation milestone.

The goal of this phase is to create the backend foundation that all later phases will build on.

## Objective

Build the initial FastAPI backend skeleton and local development foundation.

This phase establishes the Python backend without requiring frontend changes first.

By the end of Phase 1:
- the backend should start locally
- the app structure should be in place
- SQLite should be connected
- migrations should work
- core base models should exist
- a health endpoint should be available
- the codebase should be ready for Phase 2 feature work

## Scope

Included in Phase 1:
- FastAPI application setup
- backend folder structure
- configuration layer
- SQLite database setup
- ORM setup
- Alembic migration setup
- initial base models and shared model utilities
- health check route
- basic test setup

Not included in Phase 1:
- rules feature
- analytics feature
- accountability feature
- notifications
- authentication
- Supabase integration
- protected routes
- production deployment

Historical note:
- everything under `docs/` is reference material only and does not define the current implementation architecture

## Architecture Decisions

This phase uses:
- Python
- FastAPI
- SQLite
- SQLAlchemy or SQLModel
- Alembic
- pytest

This phase does not include:
- JWT auth
- Supabase
- Postgres
- microservices
- gRPC
- Kubernetes

## Deliverables

Phase 1 is complete when the project has:
- a working FastAPI app entrypoint
- a clean backend module structure
- a valid `pyproject.toml`
- app configuration loaded from one place
- SQLite database connection working locally
- ORM models and metadata registered
- Alembic initialized and able to create migrations
- an initial migration applied successfully
- a `GET /health` endpoint returning success
- a minimal automated test setup

## Proposed Folder Structure

```text
backend/
├── PLAN.md
├── PHASE1.md
├── PHASE2.md
├── pyproject.toml
├── Makefile
├── scripts/
│   └── init_env.py
├── src/
│   └── lockedin_backend/
│       ├── app/
│       │   └── main.py
│       ├── api/
│       │   └── routes/
│       ├── core/
│       ├── db/
│       ├── models/
│       ├── schemas/
│       ├── services/
│       └── repositories/
├── tests/
├── alembic/
├── alembic.ini
└── .env.example
```

## Component Plan

### 1. Application Entrypoint

Purpose:
- start the FastAPI application
- register routers
- expose the health endpoint

Implementation:
- create `src/lockedin_backend/app/main.py`
- initialize the FastAPI app
- mount API routers
- define a simple root or health route

Expected result:
- local server starts without errors

### 2. API Routing Layer

Purpose:
- organize routes by feature area
- keep app structure scalable as features are added

Implementation:
- create `src/lockedin_backend/api/routes/`
- add a health router first
- keep route registration centralized

Expected result:
- route organization exists before feature endpoints are added

### 3. Configuration Layer

Purpose:
- centralize settings and environment loading
- avoid hardcoding paths and runtime settings

Implementation:
- create `src/lockedin_backend/core/settings.py`
- define settings for:
  - app name
  - app version
  - debug mode
  - SQLite database URL
- add `.env.example`

Expected result:
- all runtime configuration comes from one place

### 4. Database Layer

Purpose:
- provide local persistence using SQLite
- create a migration-ready persistence setup

Implementation:
- create DB engine and session handling
- define declarative base or equivalent ORM base
- add reusable session dependency
- keep DB design portable for later Postgres migration

Expected result:
- application can connect to SQLite consistently

### 5. Migration Layer

Purpose:
- track schema changes in a maintainable way
- avoid manual database schema edits

Implementation:
- initialize Alembic
- connect Alembic to the ORM metadata
- generate initial migration
- apply migration locally

Expected result:
- schema creation is versioned and repeatable

### 6. Base Models

Purpose:
- establish shared model patterns before domain features are built

Implementation:
- add shared base model utilities
- define common fields where appropriate, such as:
  - `id`
  - `created_at`
  - `updated_at`
- prepare for future domain models:
  - preferences
  - rules
  - usage events
  - accountability contacts

Expected result:
- future feature models can follow a consistent pattern

### 7. Health Endpoint

Purpose:
- verify the backend is running
- support simple checks during development

Implementation:
- add `GET /health`
- return a small JSON response such as status and service name

Expected result:
- developers can quickly confirm the backend is alive

### 8. Test Foundation

Purpose:
- ensure the backend starts with testing support instead of adding it later

Implementation:
- set up pytest
- add at least:
  - app boot test
  - health endpoint test
- prepare fixtures for future database tests

Expected result:
- basic automated verification exists from the start

## Step-By-Step Implementation Plan

### Step 1: Create Project Skeleton

Tasks:
- create `src/lockedin_backend` package directories
- add `main.py`
- add placeholder modules for API, core, DB, models, schemas, services, repositories
- add `pyproject.toml`
- add minimal scripts directory
- add test directory

Output:
- clean backend structure exists

### Step 2: Add Dependencies

Tasks:
- define Python dependencies
- include FastAPI server tooling
- include ORM and migration tooling
- include test dependencies

Output:
- project dependencies are installable and clear

### Step 3: Add Settings and Environment Config

Tasks:
- create settings module
- define SQLite DB URL
- create `.env.example`
- ensure app can boot using local settings

Output:
- config is centralized and reusable

### Step 4: Set Up Database Connection

Tasks:
- create DB engine
- create session factory
- expose DB session helper
- verify local connection

Output:
- backend can talk to SQLite

### Step 5: Set Up Alembic

Tasks:
- initialize Alembic
- wire ORM metadata into Alembic
- create initial migration
- run migration locally

Output:
- database schema is migration-managed

### Step 6: Add Base Model Layer

Tasks:
- create ORM base
- define shared fields and utilities
- verify metadata loads correctly

Output:
- reusable model foundation exists

### Step 7: Add Health Route

Tasks:
- create health route module
- register router
- test route locally

Output:
- `GET /health` responds successfully

### Step 8: Add Basic Tests

Tasks:
- add test client setup
- add health endpoint test
- add startup and import smoke test

Output:
- Phase 1 foundation has basic automated verification

## Acceptance Criteria

Phase 1 is done when all of the following are true:
- backend starts locally with FastAPI
- SQLite connection works
- Alembic is configured and can apply migrations
- project structure matches the backend plan
- `GET /health` returns a valid success response
- at least one automated API test passes
- the codebase is ready for Phase 2 domain features

## Suggested Commands For Implementation

These are the kinds of commands expected during execution:
- create Python virtual environment
- install dependencies
- run FastAPI locally
- initialize Alembic
- generate and apply migration
- run pytest

Exact commands can be finalized during implementation.

## Risks And Notes

- SQLite is fine for Phase 1, but schema choices should remain portable to Postgres later.
- Auth is deferred, but database design should still keep future ownership in mind.
- Backend comes first in this phase; no frontend integration work is required yet.
- Phase 1 should avoid feature creep. The goal is foundation, not business features.
- Keep route and model naming stable now so Phase 2 can build quickly.

## Out Of Scope Reminder

Do not expand Phase 1 into:
- auth
- Supabase
- rules CRUD
- analytics endpoints
- accountability endpoints
- notification delivery
- deployment infrastructure

Those belong to later phases.

## Summary

Phase 1 establishes the backend foundation.

Highest-priority outputs:
1. FastAPI app skeleton
2. configuration layer
3. SQLite connection
4. migration setup
5. base model layer
6. health endpoint
7. basic test setup

Once Phase 1 is complete, the backend will be ready for Phase 2 implementation of real product data modules.
