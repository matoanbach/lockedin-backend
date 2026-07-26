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

The backend also has a focused onboarding set under [`backend/docs`](../backend/docs/index.md).

## Current Identity and Access Status

The current application does not implement login, authentication, authorization, or separate
admin/user roles. It uses one default development profile created by the backend. Therefore:

- there are no evaluator credentials to distribute;
- all API callers have the same effective access;
- seeded rules, usage, preferences, and contacts belong to the same profile;
- the system must remain on a trusted local/demo network;
- authentication and role-based authorization are documented limitations, not hidden features.

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
