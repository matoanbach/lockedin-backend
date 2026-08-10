# Thesis Defense Guide

This guide provides defensible answers based on the current implementation. Adapt the wording to
your own voice and do not claim features, research, or measurements that are not supported by
evidence.

## One-Minute Project Summary

LockdIn is an Android-focused digital-wellbeing prototype. A Flutter client collects usage
information from Android, lets a user configure time-limit rules, and presents dashboard and trend
views. A FastAPI modular monolith validates requests and coordinates business logic, while
PostgreSQL stores raw usage events, rules, contacts, preferences, enforcement events, and derived
daily aggregates. The design emphasizes idempotent event ingestion, failure recovery, transparent
limitations, and user-controlled Android permissions.

## Architecture Questions

### Why a modular monolith instead of microservices?

The current scope has one cohesive domain, one small team, and one database. A modular monolith
avoids network, deployment, observability, and data-consistency overhead while retaining internal
boundaries between routes, schemas, services, repositories, and models. This improves development
speed and transactional consistency for a thesis prototype. If independent scaling or team
ownership becomes necessary, analytics or ingestion could later be extracted behind the existing
service boundaries.

Trade-off: the backend scales and deploys as one unit, and a fault can affect the full API.

### How does a request travel through the backend?

FastAPI validates the HTTP payload with a Pydantic schema. A thin route receives a SQLAlchemy
session and calls a service. The service applies business rules and coordinates repositories.
Repositories operate on ORM models, and responses are serialized back to camelCase schemas.

### Why Flutter?

Flutter provides one typed UI codebase, strong widget composition, Android integration through
platform channels, and test support for controller and widget behavior. It allowed the team to
build dashboard, rules, trends, settings, and accessibility-focused UI consistently.

Trade-off: Android-specific usage and Accessibility behavior still requires native Kotlin, and
desktop builds cannot provide Android UsageStats.

### Why FastAPI and Python?

FastAPI supplies type-driven request validation, dependency injection, automatic OpenAPI/Swagger
documentation, and a small amount of routing code. Python supported rapid iteration, while
Pydantic made edge-case constraints explicit and testable.

Trade-off: Python is not selected for maximum CPU throughput. This application is primarily
database and I/O bound; workers and horizontal replicas can be added after state and operations
are production-ready.

### Why PostgreSQL?

Usage, rules, profiles, preferences, and contacts are relational and benefit from transactions,
foreign keys, uniqueness constraints, time-zone-aware timestamps, and predictable aggregation.
PostgreSQL also matches the Docker and Kubernetes deployment model.

Trade-off: daily aggregates must remain consistent with raw events. The rebuild endpoint exists
for recovery, and schema changes currently require coordinated SQL/ORM updates.

### Why Riverpod, GoRouter, and Dio?

- Riverpod separates asynchronous state and dependency wiring from widgets.
- GoRouter centralizes navigation and supports explicit routes.
- Dio centralizes base URL, timeouts, HTTP errors, and JSON requests.

These libraries reduce duplicated infrastructure code. Their version and license compatibility
must still be reviewed before external distribution.

## Custom Algorithm Questions

### How is Android usage reconstructed?

Android emits lifecycle events rather than a ready-made list of reliable sessions. Native Kotlin
sorts relevant events, tracks the foreground owner, clips sessions to the requested window, and
returns stable paginated intervals. Screen non-interactive events close visible sessions so device
lock does not inflate usage.

### Why separate the successful-sync time and usage watermark?

The successful-sync time controls the cooldown. The watermark identifies the latest completed
session uploaded. Android may publish `ACTIVITY_STOPPED` after LockdIn has already resumed and
queried. Advancing a single timestamp to wall-clock time would skip that unfinished session.
Keeping separate values allows a later sync to recover it without disabling the cooldown.

### How are duplicates prevented?

The client generates deterministic source event IDs. PostgreSQL enforces uniqueness per profile
and source ID. The service recognizes replayed IDs and reports them as duplicates instead of
adding time again. Failed uploads do not advance the watermark.

### How are Accessibility and UsageStats overlaps prevented?

Accessibility provides live `android:` intervals, while UsageStats supplies fallback
`android-usage:` intervals. Android can assign the same transition window to different package
owners. Therefore, fallback construction subtracts every uploaded live interval in the time
window, regardless of package, merges overlapping coverage, and emits only uncovered ranges.

Complexity is dominated by sorting coverage intervals, approximately `O(n log n)`, followed by a
linear scan.

### Why store raw events and aggregates?

Raw events preserve auditability and allow recomputation. Daily app/category aggregates make
dashboard queries predictable and inexpensive. This is a deliberate read-performance trade-off:
writes do more work, but derived data can be rebuilt from the source events.

## Failure and Edge-Case Questions

### What happens offline?

The UI shows a clear connection error. Failed uploads do not move the successful watermark.
Accessibility events remain queued locally, and later synchronization retries when the backend is
reachable.

### What happens if the user does not open LockdIn for several days?

Automatic UsageStats synchronization is tied to the authenticated app open/resume lifecycle, not a
scheduled daily background job. With Accessibility disabled, the fallback query recovers at most
three days, so a longer absence can leave older unsynchronized dates incomplete in the seven-day
Weekly Summary. This is an accepted prototype limitation: the current Phase 4 scope explicitly
does not require a fully continuous background analytics pipeline. If the user separately enables
Accessibility and keeps Usage Access granted, live foreground intervals can be queued while the UI
is closed and uploaded later.

### What prevents malformed usage data?

Pydantic validates count, encoded size, string lengths, time-zone awareness, valid IANA zones,
ordering, maximum six-hour duration, 90-day age, five-minute future tolerance, and within-request
same-app overlap. The service subtracts already stored same-app intervals, persists only uncovered
fragments, and treats fully covered input as duplicate rather than double-counting it.

### What if the same request is retried?

Idempotent source IDs and a database uniqueness constraint prevent double insertion. The API
reports received, created, and duplicate counts.

### What if Android permissions are revoked?

Usage sync stops and the UI guides the user to Settings. Soft enforcement depends on Accessibility,
so revoking it disables live enforcement. This is intentional respect for user control and an
Android platform limitation.

### Can a user bypass enforcement?

Yes. Force-stop, safe mode, permission removal, some OEM behaviors, work profiles, or system
restrictions can bypass a soft Accessibility-based intervention. The project does not claim
device-owner or enterprise-policy enforcement.

## Testing Questions

### What is the testing strategy?

The project uses a test pyramid:

1. backend route/service tests with pytest and isolated databases;
2. PostgreSQL smoke validation against the SQL bootstrap;
3. Flutter widget/controller tests;
4. native JUnit tests for reconstruction algorithms;
5. CI analysis, formatting, tests, and debug builds;
6. targeted physical-device system testing for Android lifecycle behavior.

See [Testing and Current Evidence](TESTING.md) for commands, verified scenarios, and gaps.

### Why not Selenium?

The primary UI is Flutter on Android, not HTML rendered into a browser DOM. Flutter widget tests
and Android physical tests are more appropriate. A future web client could justify Playwright or
Selenium.

### What coverage was achieved?

The July 25, 2026 local verification measured Flutter line coverage at 603/3,609 lines (16.71%).
Backend percentage coverage was not measured because the current dependency set does not include a
coverage plugin. The project does not enforce a coverage threshold, so the older SRS target has not
been demonstrated. The defensible answer is to show this measurement, acknowledge the gap, and
prioritize critical controller, UI, repository, and integration paths.

### How were bugs tracked?

Use issues and pull requests with reproduction steps, review discussion, regression tests, and
physical evidence. The delayed-stop watermark race and cross-source interval overlap are examples:
both were reproduced on a phone, fixed, covered by tests, and reverified.

## User-Focus Questions

### How was user feedback gathered?

Do not claim a formal usability study unless one is completed and documented. Current evidence is
informal iterative developer/evaluator feedback and hands-on device testing. The Weekly Summary
rating UI is not a persisted research instrument.

### How did feedback affect the product?

Defensible implementation examples include:

- clear offline messages that include the configured backend address;
- user-controlled permission changes through Android Settings;
- retry behavior rather than clearing user data;
- readable sync counts and permission diagnostics;
- accessibility preferences for text size, contrast, and tap targets.

Frame these as iterative design/testing decisions unless participant records demonstrate formal
user research.

### What formal user work should happen next?

Run consented task-based usability sessions, record completion/error rates, collect standardized
post-task ratings, analyze accessibility needs, and link findings to issues and design changes.
Remove personal data from research artifacts.

## Scope and Limitations

Current limitations:

- account/profile tenant foundation with an unowned default demo profile;
- Keycloak-backed mobile authentication is implemented with automated/build evidence and isolated
  physical proof of AppAuth registration/sign-in, protected-session bootstrap, authenticated
  onboarding, and local sign-out persistence; role-based admin/user workflows remain unimplemented;
- no outbound accountability email;
- no public-production security posture;
- no production HTTPS/reverse-proxy runbook;
- checked-in Kubernetes secret manifests are templates and the ingress has no TLS host;
- the Argo CD application syncs only the backend manifest path and assumes database prerequisites;
- debug API documentation remains exposed;
- one guarded Alembic migration head with passing disposable empty/legacy upgrades, fresh
  bootstrap, and dump/restore verification; target-deployment backup/restore evidence remains;
- release Android build still uses debug signing;
- Android-focused collection; no equivalent iOS implementation;
- soft rather than tamper-resistant enforcement;
- limited OEM/work-profile compatibility evidence;
- dashboard category enrichment is incomplete for unknown apps;
- no formal persisted user-feedback study;
- no full cross-stack automated UI suite;
- no measured performance/load report;
- no declared top-level project license.

Future priorities:

1. authentication and per-user authorization;
2. production secrets, HTTPS, restricted docs, and release signing;
3. restore evidence, readiness checks, metrics, and structured logs beyond the Phase B migration tooling;
4. formal usability/accessibility study;
5. broader Android compatibility and end-to-end automation;
6. notification/accountability delivery with consent and abuse controls;
7. performance benchmarks and scaling thresholds.

## Licensing and Compatibility

The repository currently has no top-level `LICENSE` file. Therefore, do not describe the project
itself as open source or approved for redistribution. Before release:

- choose and add a project license with stakeholder approval;
- inventory direct and transitive dependency licenses;
- preserve required notices;
- verify mobile-store, database, container-image, font, icon, and documentation compatibility;
- perform a legal review if distributing beyond the academic context.

## Scalability Answer

The current design is appropriate for a prototype and a small deployment. FastAPI workers and
stateless API replicas can scale reads/writes horizontally once sessions remain externalized in
PostgreSQL. Daily aggregates reduce repeated analytical work.

Before claiming production scale, measure ingestion rate, table/index growth, aggregate rebuild
time, API latency, connection-pool behavior, queue size, and device retry storms. Authentication,
rate limiting, background jobs, observability, backups, and migration procedures are prerequisites.

## Final Defense Rule

When asked about an unimplemented feature, say:

> That capability is not implemented in the current build. We deliberately kept it outside the
> verified scope. The current design leaves a clear extension point, and the next implementation
> step would be ...

An honest limitation with a concrete mitigation is more defensible than an unsupported claim.
