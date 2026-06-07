# Phase 5: Production Readiness And Deployment

## Priority

Phase 5 is the production-hardening phase.

This phase is high priority once the product loop works locally and the next goal is to run the backend reliably outside local development.

## Objective

Prepare LockdIn for a real deployed environment.

By the end of Phase 5:
- the backend should be deployable in a repeatable way
- production configuration should be explicit
- the database should be production-ready
- the frontend should be able to talk to a deployed backend cleanly
- the system should have basic operational safety for a first release

## Scope

Included in Phase 5:
- production environment configuration
- deployment packaging
- production database preparation
- schema bootstrap and startup workflow
- health and readiness improvements
- logging and operational visibility
- frontend production API configuration
- basic access protection for deployed environments

Not included in Phase 5:
- full user authentication system if still intentionally deferred
- multi-region deployment
- autoscaling optimization
- advanced observability platforms
- billing
- admin dashboard
- iOS-specific production rollout work

## Phase Direction

Phase 5 is a deployment and production-readiness phase across:
- frontend
- backend
- database

Important context:
- the backend currently runs as a FastAPI monolith
- the local database now runs from the top-level `database/` folder
- schema bootstrap is SQL-owned under `database/initdb/`
- Alembic is no longer part of the active workflow
- auth is still deferred
- the current backend is functional locally but still dev-oriented in configuration and deployment posture

## Current Local State

The repo is currently wired like this:
- `database/` owns local Postgres startup, schema bootstrap, and fake seed data
- `backend/` only connects to the initialized database through `DATABASE_URL`
- local Docker-hosted Postgres currently uses host port `5433`
- container-side Postgres still listens on `5432`
- frontend local API override can be passed with `--dart-define-from-file=.env`

Current local database URL:
- `postgresql+psycopg://postgres:postgres@localhost:5433/lockedin`

Current local frontend API override examples:
- Android emulator: `http://10.0.2.2:8000`
- desktop on the same machine: `http://127.0.0.1:8000`

## Release Goal

The goal of this phase is not to overbuild infrastructure.

The goal is:
- one reliable deployed backend
- one production database
- one clean mobile-to-backend configuration path
- one documented and repeatable deploy process

## Deliverables

Phase 5 is complete when the project has:
- a production deployment artifact such as a `Dockerfile`
- explicit production environment variables
- a production database setup
- schema bootstrap under `database/` that runs cleanly in production
- a readiness endpoint that verifies DB connectivity
- basic logs for startup and request failures
- frontend builds that target the deployed backend correctly
- a documented deploy checklist
- basic protection so the deployed API is not unintentionally open

## Frontend Todos

### Goal

Make the app work cleanly against a deployed backend.

### Tasks

- [ ] Add explicit production backend base URL configuration
- [ ] Separate dev, staging, and production API environments
- [ ] Remove dependence on local default URLs for production builds
- [ ] Verify Android release builds can connect to the deployed backend over HTTPS
- [x] Add a frontend `.env.sample` for local override workflow
- [x] Support local frontend config through Flutter `--dart-define-from-file`
- [ ] Add clear UI handling for:
  - no connection
  - request timeout
  - server error
- [ ] Verify queued usage uploads still behave correctly with real network latency
- [ ] Smoke test these flows against the deployed backend:
  - onboarding
  - preferences sync
  - rules CRUD
  - usage sync
  - analytics
  - enforcement event upload

### Exit Criteria

- production app builds target the correct backend without code changes
- backend failures produce understandable UI states
- core user flows work against the deployed backend

## Backend Todos

### Goal

Make the FastAPI service safe and repeatable to deploy.

### Tasks

- [ ] Add explicit production settings
- [ ] Make `DEBUG` false in production
- [x] Read the backend database connection from `DATABASE_URL`
- [ ] Require explicit `DATABASE_URL` in production
- [ ] Add a deployment artifact such as a `Dockerfile`
- [ ] Define the production app start command
- [x] Remove Alembic from the active backend workflow
- [ ] Define the database bootstrap command for deployment
- [ ] Add a readiness endpoint that verifies database connectivity
- [ ] Keep a simple liveness endpoint
- [ ] Add basic structured logging for:
  - app startup
  - request failures
  - database failures
- [ ] Add basic access protection for deployed environments
- [ ] Harden write paths for concurrency and duplicate requests
- [ ] Catch and handle database integrity conflicts cleanly
- [ ] Document required environment variables
- [ ] Document deploy, bootstrap, and rollback steps

### Access Protection Note

If full auth is still deferred, Phase 5 must still include one of:
- private network access
- gateway/API key protection
- another intentional access restriction layer

Public anonymous production APIs are not acceptable.

### Exit Criteria

- the backend starts cleanly in a production environment
- database bootstrap can be run repeatably
- DB readiness is checked explicitly
- failures are visible in logs
- the deployed API is intentionally protected

## Database Todos

### Goal

Move from local-development persistence to production-safe persistence.

### Tasks

- [x] Move the active local workflow to Postgres
- [x] Move schema/bootstrap ownership into `database/`
- [x] Validate the SQL bootstrap files against Postgres locally
- [x] Confirm schema creation works from an empty local Postgres database
- [ ] Review indexes and constraints for production usage
- [ ] Verify usage event deduplication works correctly under retries
- [ ] Review aggregate update behavior under concurrent writes
- [ ] Configure production connection settings
- [ ] Ensure persistent storage and backup strategy exist
- [ ] Document restore expectations

### Concurrency Note

Current usage ingestion and aggregate updates should be reviewed carefully for race conditions under concurrent requests.

### Exit Criteria

- Postgres is the production database
- schema bootstrap runs successfully on Postgres
- retries and duplicate submissions do not corrupt usage totals
- operational basics exist for persistence and recovery

### Current Validation

Already verified locally:
- `database/docker-compose.yml` starts Postgres on host port `5433`
- `database/initdb/10-schema.sql` creates the backend-compatible schema
- `database/initdb/20-seed.sql` inserts fake development data
- backend reads live rules and analytics data from that Postgres database

## Recommended Implementation Order

1. Database
- move production target to Postgres
- validate schema bootstrap
- review constraints and concurrency behavior

2. Backend
- add production config
- add readiness checks
- add deploy artifact
- add logging
- add access protection
- document deploy flow

3. Frontend
- wire production backend configuration
- validate release behavior against deployed backend
- test failure states and sync behavior

## Deployment Checklist

Before first production deploy:
- [ ] production database exists
- [ ] schema bootstrap has been run
- [ ] backend environment variables are set
- [ ] backend readiness endpoint passes
- [ ] frontend build points to the deployed backend
- [ ] HTTPS connectivity is verified
- [ ] logs are visible
- [ ] API access is intentionally protected
- [ ] core mobile flows have been smoke tested

## Definition Of Done

Phase 5 is done when:
- the backend can be deployed repeatably
- the database is production-safe
- the frontend can use the deployed backend without local assumptions
- the deployed system has basic operational safety for a first real release
