# Roadmap And Planning

This page helps new contributors understand what is already implemented versus what is still planned.

Use this page after you have already read the operational onboarding pages. It is meant to provide context, not to replace the getting-started and architecture docs.

If you are new to the repo, do not start here.

## What Is Operational Today

The backend currently has working support for:

- health endpoint
- rules CRUD
- rule status summaries
- usage ingestion
- analytics endpoints
- accountability contacts
- preferences read/update
- enforcement event logging
- local Docker runtime
- local Postgres bootstrap through the top-level `database/` folder

## Important Current Limits

- no auth yet
- current runtime is effectively single-profile
- health is liveness-oriented, not DB readiness-oriented
- production hardening is still incomplete
- schema evolution is SQL-bootstrap driven, not migration-driven

## Planning Files

Main planning/context files in this directory:

- `PLAN.md`
- `PHASE1.md`
- `PHASE2.md`
- `PHASE3.md`
- `PHASE4.md`
- `PHASE5.md`

## How To Read Them

- `PLAN.md` explains the broad backend direction.
- `PHASE1.md` to `PHASE4.md` capture earlier implementation planning stages.
- `PHASE5.md` covers production-readiness and deployment planning.

These are useful context, but they are not the best first docs for onboarding. Start with the docs under `backend/docs/` first.

## Historical Docs Note

The broader repo-level `docs/` folder is historical/reference material and should not be treated as the current backend source of truth.

For active backend development, prefer:

1. runtime code under `backend/src/lockedin_backend/`
2. backend onboarding docs under `backend/docs/`
3. top-level `database/` for SQL bootstrap behavior
4. planning files like `PLAN.md` and `PHASE*.md` for context

## Recommended Team Onboarding Order

1. `backend/README.md`
2. `backend/docs/getting-started.md`
3. `backend/docs/architecture.md`
4. `backend/docs/layers.md`
5. `backend/docs/api.md`
6. `backend/docs/testing.md`

## Related Pages

- [Docs home](index.md)
- [Architecture](architecture.md)
- [Deployment](deployment.md)
