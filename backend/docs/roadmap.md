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

- no real Keycloak authentication yet; protected routes fail closed
- tenant/account ownership exists, but account bootstrap is not exposed
- health is liveness-oriented, not DB readiness-oriented
- production hardening is still incomplete
- one guarded Alembic migration head exists; disposable empty/legacy upgrades, fresh bootstrap,
  triggers, two-account isolation, and dump/restore pass, while target-deployment evidence remains

## Next Major Initiative: Identity And Tenant Isolation

The initiative is intentionally split into reviewable stages:

1. accept the local technical and role-based ownership decisions in the
   [Authentication, Session, and Tenant-Isolation ADR](decisions/authentication-session-tenant-isolation.md);
2. add a safe migration mechanism, account/profile ownership, current-principal dependency, and
   tenant-scoped services/repositories — **implemented in Phase B**;
3. implement the approved backend signup/OIDC, verification, login, renewal, logout/revocation,
   recovery, throttling, and audit contract;
4. implement Flutter auth state, platform-backed credential storage, guarded routing, and
   account-scoped cache/queue lifecycle;
5. complete two-account isolation, adversarial auth, mobile lifecycle, TLS/secret, deployment, and
   rollback verification.

The ADR's D1–D6 decisions are accepted for local implementation. Do not describe authentication as
implemented until working controls and acceptance evidence exist. Do not enable shared/external
exposure until the actual role holders, contacts, access, runbooks, and remaining production gate
are verified.

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

## Project-Wide Docs Note

The broader repo-level `docs/` folder contains current user, evaluator, testing, defense, and
security guides alongside older academic requirement/design reports. Start with `docs/README.md`
to distinguish current operational guidance from historical material.

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
