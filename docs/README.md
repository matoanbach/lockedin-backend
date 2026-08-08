# LockdIn Documentation

This folder contains project-wide documentation for developers, evaluators, testers, and thesis
reviewers. Runtime code and generated API schemas remain the source of truth when a historical
report disagrees with the current implementation.

## Start Here

| Audience | Recommended document |
| --- | --- |
| New developer | [Repository README](../README.md) |
| End user or tester | [User Guide](USER_GUIDE.md) |
| Live evaluator | [Demo Walkthrough](DEMO_WALKTHROUGH.md) |
| Thesis team | [Thesis Defense Guide](THESIS_DEFENSE_GUIDE.md) |
| QA or reviewer | [Testing and Evidence](TESTING.md) |
| Requirements reviewer | [Requirements Implementation Status](IMPLEMENTATION_STATUS.md) |
| API consumer | [API Reference](../backend/docs/api.md) |
| Security reviewer | [Security Testing Plan](security/security-testing-plan.md) |
| Authentication architecture reviewer | [Authentication, Session, and Tenant-Isolation ADR](../backend/docs/decisions/authentication-session-tenant-isolation.md) |

The backend also has a focused onboarding set under [`backend/docs`](../backend/docs/index.md).

## Current Identity and Access Status

The Phase B tenant foundation is implemented: accounts link immutable provider identities to one
non-demo profile, services require a server-derived tenant, and user-facing routes fail closed.
Real Keycloak token introspection and the mobile login flow are not implemented. Therefore:

- there are no evaluator credentials to distribute;
- protected API requests return `401` unless tests or a later authenticator supply a trusted
  `CurrentPrincipal`;
- the seeded default profile remains demo-only, unowned, and unavailable through protected routes;
- aggregate rebuild requires a separate operator dependency;
- the system must remain on a trusted local/demo network.

The approved local next-state design is recorded in the
[Authentication, Session, and Tenant-Isolation ADR](../backend/docs/decisions/authentication-session-tenant-isolation.md).
Its Phase B foundation is now reflected in runtime and schema code. Phase C identity/session
controls and Phase D mobile lifecycle work remain pending. Role-based operational ownership is
approved; acting people and runbooks still require verification before release completion or
external exposure.

## Historical Documents

These documents capture earlier requirements and design work:

- [User Requirements](LockdIn_User_Requirements.md)
- [Software Requirements Specification](LockdIn_SRS.md)
- [System Design Report](LockdIn_System_Design_Report.md)
- [Prototype Report](LockdIn_Prototype.md)
- [QA Plan](LockdIn_QA.md)

They are useful academic records, but may contain planned behavior that differs from the current
implementation. Use the repository README, current source code, OpenAPI export, and guides above
for operational instructions.

## Media Status

Actual product screenshots and a video walkthrough are not currently checked in. The
[media capture checklist](MEDIA_CAPTURE_CHECKLIST.md) defines the required views, privacy checks,
file names, and acceptance criteria. Generated mockups must never be labeled as product
screenshots.
