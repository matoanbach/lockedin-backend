# Testing Strategy and Current Evidence

This document describes tests present in the repository and verified system behavior. It does not
claim unmeasured coverage or tests that have not been run.

## Test Layers

| Layer | Tools | What it covers |
| --- | --- | --- |
| Backend route/service tests | pytest, FastAPI TestClient, SQLAlchemy, SQLite fixtures | validation, status codes, services, repositories, serialization |
| PostgreSQL smoke test | pytest, psycopg, Docker PostgreSQL | initialized schema and runtime connectivity |
| Flutter unit/widget tests | `flutter_test` | app rendering, usage-sync controller behavior, rule warning widgets |
| Android native unit tests | JUnit 4, Gradle | UsageStats reconstruction and interval subtraction |
| Static analysis | Flutter analyzer, Dart formatter | frontend correctness and style |
| CI build checks | GitHub Actions | Android debug APK and Windows debug build |
| Physical system tests | Samsung SM-A528B, Android 14 | usage lifecycle, permissions, PiP, lock, offline recovery, rapid switching |
| Security planning | documented manual/automated plan | input, configuration, mobile, API, dependency, and deployment risks |

There is no Selenium suite because the primary client is Flutter/Android, not a browser DOM
application. There is no committed full cross-stack UI automation suite yet.

## Commands

Backend:

```bash
cd backend
make test
make test-postgres
```

Frontend:

```bash
cd frontend/flutter_app
flutter analyze
flutter test --coverage
dart format --set-exit-if-changed .
```

Android native:

```powershell
Set-Location frontend/flutter_app/android
.\gradlew.bat testDebugUnitTest
```

Build:

```bash
cd frontend/flutter_app
flutter build apk --debug --dart-define-from-file=.env
```

Documentation/API:

```bash
cd backend
make export-openapi
make build-docs
```

## CI Behavior

GitHub Actions:

- runs backend pytest tests;
- initializes PostgreSQL from the checked-in SQL and runs the smoke test;
- runs Flutter analysis and formatting checks;
- runs Flutter tests with coverage generation;
- uploads coverage to Codecov without failing the build if upload fails;
- builds Android and Windows debug artifacts.

The repository does not currently enforce a numeric coverage threshold. Do not claim the SRS
coverage target has been met until a measured report confirms it.

## Verification Snapshot — July 25, 2026

| Check | Result |
| --- | --- |
| Backend pytest | 56 passed, 1 skipped |
| Flutter analyzer | No issues found |
| Flutter tests | 12 passed |
| Flutter line coverage | 603/3,609 lines, 16.71% |
| Android/Gradle unit tests | `BUILD SUCCESSFUL`; 82 actionable tasks |
| Strict MkDocs build | Passed |
| Generated OpenAPI validation | OpenAPI 3.1.0; 14 paths; 18 operations |
| Documentation local-link check | 17 key Markdown files passed |

Flutter coverage was measured from `coverage/lcov.info` produced by `flutter test --coverage`.
Backend percentage coverage was not measured because the current development dependency set does
not include a coverage plugin. The Flutter result is below the older SRS target and is explicit
test debt, not a passing coverage claim.

## Physical Android Regression Evidence

The merged usage-synchronization fixes were exercised on:

- Samsung SM-A528B;
- Android 14 / API 34;
- physical Wi-Fi connection to the local backend;
- preserved application data and PostgreSQL volume.

Verified scenarios:

| Scenario | Observed result |
| --- | --- |
| Back navigation | A delayed stop event was recovered later as one full session |
| Picture-in-Picture | Usage continued while visible and ended when PiP closed |
| Screen lock | Main session ended at screen non-interactive; unlock did not extend it |
| Backend offline/reconnect | Failed sync wrote nothing; reconnect imported pending intervals |
| Rapid app switching | No duplicate source IDs or overlapping test intervals |
| Accessibility live tracking | Live `android:` events uploaded without fallback rows |
| Accessibility disabled | UsageStats fallback excluded all live intervals across packages |
| Repeated manual sync | No new rows after automatic sync had completed |

Final cross-source verification:

- 13 post-baseline live rows;
- 18 post-baseline UsageStats fallback rows;
- zero new overlap pairs;
- zero duplicate source IDs;
- HTTP `200` for usage uploads;
- no current crash or out-of-memory exit;
- Accessibility restored to disabled;
- Usage Access remained allowed;
- notifications remained denied.

Six historical diagnostic overlap pairs were intentionally preserved. They predate the fix and
must not be presented as newly created failures.

## Edge Cases Covered in Code

- duplicate source IDs and replay;
- overlapping usage intervals;
- invalid or blank fields;
- invalid email addresses;
- duplicate accountability contacts;
- unknown rule/contact identifiers;
- negative or zero limits;
- invalid date ordering;
- naive timestamps;
- invalid IANA time zones;
- stale and future usage events;
- oversized event batches;
- unfinished Android sessions;
- unsorted and overlapping coverage intervals;
- offline upload retry;
- automatic-sync cooldown;
- invalid Android batch cursors.

## Bug Tracking and Evidence

Use GitHub issues and pull requests as the traceable record for defects and fixes. Each defect
report should include:

- environment and commit;
- reproduction steps;
- expected and actual result;
- logs or sanitized screenshots;
- risk/severity;
- regression test added;
- physical verification when Android lifecycle behavior is involved.

Do not delete diagnostic rows or artifacts merely to make a test report appear clean.

## Current Testing Gaps

- no full Flutter-to-backend automated end-to-end suite;
- no formal usability test report with participant data;
- no enforced coverage threshold;
- limited PostgreSQL integration coverage;
- no committed load/performance benchmark;
- no iOS system test;
- no work-profile, multi-user, cloned-app, or broad OEM compatibility matrix;
- no production penetration-test report;
- no automated release-signing verification.

These gaps should be stated during the defense and prioritized according to deployment risk.
