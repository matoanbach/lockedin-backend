# Testing Strategy and Current Evidence

This document describes tests present in the repository and verified system behavior. It does not
claim unmeasured coverage or tests that have not been run.

## Test Layers

| Layer | Tools | What it covers |
| --- | --- | --- |
| Backend route/service tests | pytest, FastAPI TestClient, SQLAlchemy, SQLite fixtures | validation, status codes, services, repositories, serialization |
| PostgreSQL smoke test | pytest, psycopg, Docker PostgreSQL | initialized schema and runtime connectivity |
| Flutter unit/widget tests | `flutter_test` | app rendering, usage-sync controller behavior, rule warning widgets |
| Android native unit tests | JUnit 4, Gradle | UsageStats reconstruction, interval subtraction, exact-time enforcement, and warning copy |
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

## Physical Soft-Enforcement Boundary Evidence — July 28, 2026

The boundary policy was exercised on the Samsung SM-A528B with preserved app data and the local
backend. The installed debug APK was built with `--dart-define-from-file=.env`; its local and
on-device SHA-256 values matched.

Observed native and backend evidence:

| Boundary | Observed result |
| --- | --- |
| `4/5` minutes | One `warning_approaching_limit` notification and backend event |
| `5/5` minutes | One `warning_limit_reached` notification and backend event |
| Exact limit | Soft intervention queued in the same native evaluation tick and removed Messages from the foreground |
| Dismissal | `stay_in_lockdin` recorded as `intervention_dismissed` |
| Final device state | Accessibility disabled and unbound; Usage Access allowed; no crashed service |

Disabling Accessibility after the first run exposed one `warning_limit_reached` duplicate from
`app_sync` at `6/5`. The row and notification were preserved as diagnostic evidence. The cause was
the legacy Dart `SharedPreferences` cache not observing a marker written directly by native
Android code. The alert path now reloads preferences before dedupe reads, and a regression test
simulates a native marker arriving after Dart cached the store. The final APK resume smoke check
created no additional notification or enforcement event.

The `6/5` value did not show another minute of Messages usage after intervention. The preserved
July 28 raw events total 315.400 seconds for Messages. The code at the time used
`ceil(total_seconds / 60)`, producing six displayed minutes. That event remains preserved as
historical diagnostic evidence.

## Automated Exact-Time Policy Evidence — July 28, 2026

The approved replacement policy uses raw elapsed milliseconds for rule status, warnings,
intervention, analytics comparisons, and Android backend-plus-live accounting. Whole-minute
fields and UI totals represent only completed minutes. A positive remainder below one minute is
rendered as “less than 1 minute” where the distinction matters.

| Exact usage | Completed minutes | Rule status | Blocked |
| ---: | ---: | --- | --- |
| 299.9 seconds | 4 | `approaching_limit` | No |
| 300.0 seconds | 5 | `at_limit` | Yes |
| 300.1 seconds | 5 | `over_limit` | Yes |
| 315.4 seconds | 5 | `over_limit` | Yes |
| 359.9 seconds | 5 | `over_limit` | Yes |

Backend tests confirm the status contract, exact analytics percentages, completed-minute
dashboard values, and aggregate flooring. Android JVM tests confirm that exact backend
milliseconds and the live local remainder reach the limit without delay. Flutter tests confirm
sub-minute remaining copy and completed-minute rendering. No aggregate rebuild, raw-event edit,
or diagnostic-event edit was performed.

## Physical Exact-Time Synchronization Smoke Check — July 29, 2026

The exact-time implementation at commit `60042dc` was installed in place on the Samsung SM-A528B
with preserved app data. The backend image was rebuilt and only the backend container was
recreated; the existing PostgreSQL container and volume remained running and healthy. No SQL,
aggregate rebuild, historical event edit, or diagnostic-event edit was performed.

The debug APK was built with `--dart-define-from-file=.env` for
`http://192.168.2.44:8000`. Its SHA-256 was
`2558A0C43545B3685E97225C9E8C46CFD7ACE7792CC670479641EA5DF07276D3`, and `adb install -r`
completed successfully without changing the original first-install timestamp.

A controlled Messages foreground session synchronized through the normal UsageStats path. The
phone became non-interactive during the intended 35-second interval, so the authoritative observed
duration was 8,946 milliseconds rather than 35 seconds. The rebuilt backend returned:

- `usedMilliseconds: 8946`;
- `usedMinutes: 0`;
- `remainingMilliseconds: 291054`;
- `remainingMinutes: 4`;
- `progressPercent: 3`;
- `status: under_limit`;
- `isBlockedNow: false`.

The native `lockdin_enforcement` cache stored the same 8,946-millisecond backend value. The Rules
screen rendered `Messages`, `<1m used`, `Used: <1m`, `Left: 4m`, and `3%`. After a home/resume
cycle and another rule-status refresh, the backend, native cache, and Rules UI retained the same
exact sub-minute value. This physically verifies in-place installation, exact sub-minute backend
status, Android cache retention across refresh, and completed-minute/sub-minute UI copy.

This was intentionally a narrow smoke check. It did not repeat the physical 299.9/300.0/300.1,
315.4, or 359.9-second boundaries, Accessibility intervention, warning deduplication, or full
dashboard/analytics reconciliation. Those boundaries retain automated evidence, while the earlier
July 28 exact five-minute intervention remains the physical enforcement evidence.

Final device state: Accessibility flag `0`, no enabled/bound/binding/crashed Accessibility
services, Usage Access allowed, and LockdIn in the foreground.

This evidence verifies the implemented user-revocable soft intervention. It does not verify or
claim non-bypassable Device Owner, LockTask, backend lock-command, PIN/wait, or tamper-resistant
enforcement.

## Physical Exact-Limit and Navigation Retest — July 29, 2026

The navigation-fix debug APK from commit `050e42c` was built with
`--dart-define-from-file=.env`, produced SHA-256
`93E1A2E9BB2D4878466D3130CB65F323E421808AD22C0C73DB5B2B58DA307AE3`, and was installed in
place on the Samsung SM-A528B with application data preserved.

The user manually repeated the exact-limit intervention and reported that it activated accurately.
After choosing “Stay in LockdIn,” the restored Rules page was tested through both exit paths:

- the Rules top-left arrow returned to Dashboard;
- Android system Back returned to Dashboard instead of exiting LockdIn;
- Dashboard and Rules continued to load.

During the verification, the read-only rule-status response for Messages reported
`usedMilliseconds: 318793`, `usedMinutes: 5`, `limitMinutes: 5`,
`remainingMilliseconds: 0`, `progressPercent: 106`, `status: over_limit`, and
`isBlockedNow: true`. The exact duration was 5 minutes 18.793 seconds. The percentage is
`round(318793 / 300000 * 100) = 106`, while the `5m` usage label correctly shows completed
minutes. This physically confirms that the over-limit percentage and completed-minute display use
their intended exact-time semantics.

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
