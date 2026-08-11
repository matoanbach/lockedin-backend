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
| Generated OpenAPI validation | OpenAPI 3.1.0; 20 paths; 24 operations |
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

## Physical Disabled-Rule CRUD Regression — July 31, 2026

An earlier exploratory TikTok CRUD run exposed a confirmed UI defect: the edit control was inside
an `if (enabled)` footer, so a disabled rule had to be enabled before it could be edited or
deleted. That forced-enable workflow created an unnecessary opportunity to touch another card's
switch. Messages received a separate disable update during that earlier test window, but the
relevant pre-restart request log was unavailable. An accidental Messages interaction remains the
leading explanation, not a proven root cause; TikTok deletion, database cascades, and automated
rule-disabling paths were ruled out.

The regression APK made the rule-card footer unconditional, retained the existing enabled/blocked
copy, added neutral `Rule disabled` copy, and exposed an `Edit rule` control in both states. It was
built with `--dart-define-from-file=.env`, produced SHA-256
`7CA3F1C1849933300E4E44927E53B059F57BA43C83389487C21A01972878D14B`, and was installed in
place on the Samsung SM-A528B with application data preserved.

The user performed every phone interaction manually. Read-only API checks were captured after
each mutation:

| Step | Physical and API result |
| --- | --- |
| Baseline | Instagram, Messages, and Spotify disabled; YouTube enabled |
| Create | TikTok created disabled at 180 minutes with canonical package `com.zhiliaoapp.musically`; the edit control was immediately visible |
| Edit | The same rule ID `c8aceaa0-bada-4962-9072-dd5d0049e07c` became `TikTok Test` with a 1,440-minute limit while remaining disabled; the card showed `Used: 0m`, `Limit: 24h`, and `Left: 24h` |
| Delete | The disabled rule was deleted through its existing confirmation dialog; both TikTok rule and status counts returned to zero |
| History | Trends retained TikTok's historical 176-minute usage entry after rule deletion |
| Isolation | Every unrelated rule retained its baseline enabled state after create, edit, and delete |

Focused widget coverage verifies that a disabled card exposes and invokes `Edit rule`, enabled
cards retain editing, disabled usage-tracking copy remains accurate, and tapping one card's switch
invokes only that card's callback. The focused file passed 14 tests; the complete Flutter suite
passed 29 tests. `flutter analyze --fatal-infos`, the repository-wide Dart formatting check, and
`git diff --check` also passed. This evidence verifies the current per-app daily create, edit,
enable/disable, and delete workflow. It does not broaden the supported rule model to weekly,
category, schedule, recurrence, exception, or version-history behavior.

## Physical Analytics and Weekly UX Verification — August 1, 2026

The Samsung SM-A528B remained on Android 14 / API 34 with application data and the PostgreSQL
volume preserved. The user performed every phone interaction and permission action manually.
Codex used ADB only to replace the debug APK in place.

The user physically verified the following behavior against read-only API responses captured at
the same point in time:

- known packages were shown with friendly labels, including WhatsApp, One UI Home, TikTok,
  Chrome, and Clock;
- analytics categories used a curated, package-based descriptive taxonomy and did not claim that
  an app or behavior was productive, good, or bad;
- exact category duration was preserved, and positive usage below one completed minute rendered
  as `<1m` rather than `0m`;
- Dashboard showed `17h 53m` and Trends showed `17.9h`, both representing the authoritative
  1,073-minute weekly total rather than a sum of independently rounded daily chart values;
- **View Weekly Summary** was visible and opened Weekly Summary; the non-persistent rating and
  feedback controls were absent;
- **Weekly Highlights** contained exactly **Goal Progress** and **Best Streak**, with explanatory
  copy that describes those two summaries factually;
- developer-oriented `HLR-*` badges were absent from the user interface;
- category colors were distinguishable, and the first two Top Apps rank colors for WhatsApp and
  One UI Home were also distinguishable;
- **Add Rule** opened the creation form directly, while **Rules** opened only the overview; and
- the checked narrow and physical layouts had no clipping or overflow.

The read-only API snapshot used for reconciliation was:

| View | Recorded values |
| --- | --- |
| Dashboard | `todayTotalMinutes: 54`; `weeklyTotalMinutes: 1073`; Social & Messaging `1,673,860 ms` / `27m`; System & Utilities `917,835 ms` / `15m`; Video & Entertainment `565,060 ms` / `9m`; Other `104,859 ms` / `1m` |
| Trends | `weeklyTotalMinutes: 1073`; WhatsApp `369m`; One UI Home `280m`; TikTok `125m`; Chrome `84m`; Clock `48m`; peak window `11 PM - 1 AM` |
| Weekly Summary | screen-time reduction `-68%`; total `17.9h`; daily average `2.6h`; goals met `4`; longest streak `7` |

These values are a moment-in-time observation, not fixtures. They can legitimately advance as new
usage arrives and can change at midnight rollover. Classification is applied when analytics are
read; no historical usage rows were renamed or reclassified.

The final debug APK was built with `--dart-define-from-file=.env`, installed in place, and retained
application data. It is 173,928,253 bytes with SHA-256
`3872BCE8F87388F8DC083E00DF6F681F9D7644E11E0A4D64CA0A9931666067E0`. Automated regression
coverage also verifies distinct Top Apps colors, unique whole-hour labels on the weekly chart, and
one Peak Usage Window insight instead of two repeated callouts. On the installed final build, the
user confirmed that the weekly Y-axis had no duplicate hour labels and that only the contextual
Peak Usage Window card beneath Usage by Time of Day remained.

Current semantic limitation: once any usage history exists, Weekly Summary currently treats
missing dates as zero-usage successful days when calculating goals met and longest streak. A
synchronization or data-gap day can therefore be counted as successful. This behavior was not
changed during analytics clarification.

## Physical Phase D Authentication Evidence — August 8–9, 2026

An isolated Docker project with newly created disposable volumes was exercised from a Samsung
SM-A528B without clearing or uninstalling the existing app. A purpose-specific local CA was trusted
for the test and the phone reached the isolated Caddy edge over an ADB loopback reverse. No
preexisting LockdIn or Keycloak database volume participated.

| Step | Physical and stack result |
| --- | --- |
| Flutter bootstrap and TLS | Flutter retrieved configuration through CA-validated HTTPS on the phone. |
| Registration | AppAuth opened Chrome on the real Keycloak registration form; `prompt=create` was observed. |
| Verification delivery | The isolated Mailpit instance received one matching `Verify email` message; the synthetic account became verified. |
| Normal sign-in | AppAuth opened the email/password form, accepted the verified synthetic identity, and redirected to `com.lockdin.lockdin_app`. |
| Token and protected session | Sanitized edge evidence recorded token exchange `200`, introspection `200`, and `GET /api/v1/auth/session` `200`. |
| Authenticated app state | LockdIn displayed authenticated onboarding and completed it into the Dashboard. No unclaimed-data choice appeared. |
| Long-offline session | An older stored session attempted refresh and received `400`; the app entered terminal reauthentication and cleared native auth context instead of reusing the stale session. This is failure-path evidence, not successful-refresh evidence. |
| Sign-out | Settings sign-out returned to the welcome screen; after force-stop/relaunch, Sign in and Create account remained visible and authenticated routes did not return. |
| Fresh access-token refresh | After a fresh protected `200` baseline, the app remained untouched for more than the realm's 300-second access-token lifetime. A process-only relaunch then produced another protected-session `200`; LockdIn remained the resumed activity and no Chrome/provider reauthentication transition occurred. |
| SQLite v1-to-v2 migration | An isolated test package used the authentic v1 queue writer, then upgraded in place with the current application. Its one synthetic row survived with all non-owner fields preserved, owner `unclaimed`, schema version 2, no legacy table, and the exact `(owner_generation, source_event_id)` unique-index columns. |
| Authenticated queue ownership | A current-revision instrumentation test added one controlled row for each of the active, unclaimed, and quarantined owners. Only the active row uploaded; the other two remained locally pending. Targeted teardown restored the exact queue baseline. |
| Backend upload corroboration | A count-only query for the three controlled source IDs returned active/unclaimed/quarantined counts of `1/0/0`; no full usage rows or identity fields were inspected. |

The run also exposed and fixed two disposable-realm integration defects: the custom browser flow
now nests required executions under a supported alternative subflow, and the mobile client includes
Keycloak's built-in `basic` scope so token introspection supplies the required `sub` claim. The
backend continued to reject tokens without `sub`; validation was not weakened.

The August 9 routing was disposable validation scaffolding. Because ADB could not bind privileged
device port 443, device port 8443 was reversed to a loopback-only Caddy edge. A raw TCP sidecar
shared the backend network namespace and forwarded backend loopback 8443 to the edge so Keycloak
introspection could retain the external issuer. It did not terminate or inspect TLS, and CA,
hostname, issuer, and per-request introspection validation remained enabled. This topology is not
a production deployment design.

At PR #45's merge commit, all 58 Flutter tests and all 123 backend tests passed, with 3 expected
backend skips. PR #45 CI passed Backend test, Frontend analyze, Frontend tests, Android APK build,
and Windows build. August 9 logout/revocation regression evidence from the merged implementation
remained passing alongside the physical refresh, migration, and queue-ownership checks above.

This evidence does **not** establish refresh of an arbitrarily old provider session, password-
recovery delivery, migration of the main installed package's preexisting database, backup/restore
behavior, Phase E adversarial and release controls, shared/external deployment safety, or
production readiness.

## Account-Deletion and Category Drill-Down Evidence — August 9–10, 2026

Follow-up implementation after the physical Phase D run adds:

- fresh system-browser reauthentication before account deletion;
- a server-side exact active-account match so another reauthenticated account cannot be deleted;
- fail-closed rejection without auto-provisioning for an unknown deletion identity;
- provider identity deletion followed by profile-owned backend deletion;
- de-identification of retained security-audit linkage;
- deletion of only the active account generation's local queues, watermarks, and warning markers,
  plus removal of every installation binding after authoritative deletion under the current
  one-account-per-installation scope;
- a one-account-per-installation guard that hides account creation on returning devices and rejects
  a different account without replacing the existing binding; and
- same-day per-app details inside clickable dashboard categories.

The complete backend suite passed with 132 tests and 3 expected skips. After the physical follow-up
fixes, the complete Flutter suite passed 70 tests, Flutter analysis reported no issues, and Android
JVM tests plus the debug build completed successfully.

On August 10, the Samsung SM-A528B physically completed freshly reauthenticated account deletion
against the disposable validation stack. The first deletion request had returned `503` before the
Keycloak service account received its narrow `realm-management/manage-users` client scope mapping.
After that repair, the same active disposable account completed the system-browser
**Sign in to your account** step, `DELETE /api/v1/auth/account` returned `204`, LockdIn displayed
**Welcome to LockdIn** rather than **Sign in again**, and Keycloak rejected the deleted credentials
with its generic invalid-credentials response. Count/status-only corroboration found one
de-identified successful-deletion audit event and no additional deletion request.

The physical run exposed two post-`204` client defects. Reconstructing `GoRouter` during the auth
transition caused a Flutter render-tree assertion; the router is now stable and refreshes its
redirect from auth state. A stale installation binding also hid **Create account** after deletion;
successful deletion now clears all installation bindings and empty secure binding storage deletes
the key. The authorized recovery removed only that already-stale binding from the validation
installation. **Create account** then appeared. The main SQLite database remained 28,672 bytes with
timestamp `1786304505` throughout in-place APK installation and recovery. The accepted APK is
193,268,122 bytes with SHA-256
`D0125033353081EB10E39E0518CDED39C38F24F5FCCEBA966E06EB109C48681E`.

Account deletion and the single-account returning/deleted-device screens therefore have physical
acceptance. Category drill-down has not yet been accepted on a physical device. Same-device
multi-account switching is explicitly deferred. The repository still lacks a public external web
deletion-request resource and production retention, backup-deletion, and recovery procedures.

## Physical Picture-in-Picture Soft-Intervention Regression — August 10, 2026

The PiP regression debug APK was built with `--dart-define-from-file=.env`, produced SHA-256
`1CF4A20CD31D777A40C76B8CC5953F3076D44BFAF9713447F3344A2AC24912B9`, and was installed in
place on the Samsung SM-A528B with application data and Usage Access preserved. The user manually
renewed the authenticated session and enabled the LockdIn Accessibility service; ADB confirmed the
service was enabled and bound with interactive-window retrieval before the test.

For the accepted final-APK run, the user extended the existing YouTube rule from two to five
minutes instead of deleting retained usage history. Native evaluation began at
`usedMillis=195932`, emitted the approaching warning at `usedMillis=240961`, and crossed the
five-minute threshold at `usedMillis=301048`. The same evaluation queued the intervention for
`com.google.android.youtube`; LockdIn came to the foreground and displayed its intervention dialog.

Android briefly reported the target-owned YouTube window in pinned/PiP mode. On the first bounded
check, LockdIn dispatched the media-pause key and Android accepted the PiP root's advertised
dismiss action. The exact native log was
`Handled target PiP package=com.google.android.youtube paused=true dismissed=true attempt=0`.
The user observed no YouTube PiP remaining over LockdIn. The post-intervention window state showed
LockdIn as the resumed, focused, visible fullscreen app and YouTube as invisible and fullscreen,
not pinned.

This physically verifies both parts of the soft regression handling in the accepted final APK:
launching LockdIn directly no longer leaves YouTube playing visibly over the intervention, and a
target-owned PiP window that appeared transiently was paused and dismissed when Android advertised
that action. It does not establish that LockdIn can forcibly close every third-party PiP window.
Android exposes PiP-window detection, media-pause dispatch, and node dismissal only when the
window advertises dismissal, so the fallback remains a user-revocable soft intervention rather
than a hard or non-bypassable lock.

After testing, the user manually disabled Accessibility. ADB confirmed Usage Access remained
allowed, `accessibility_enabled` returned `0`, the enabled-service setting was empty, and both the
bound and enabled Accessibility service sets were empty.

## Physical Private-Tailnet Migration Evidence — August 10, 2026

The existing Samsung SM-A528B installation and persistent Docker volumes were migrated from the
disposable IP/ADB routing to a private Tailscale Serve origin. The real machine and tailnet names
remain in ignored local environment files and are not recorded in the repository. Funnel was not
enabled; PostgreSQL, FastAPI, Keycloak, and Keycloak PostgreSQL remained container-only. The HTTP
edge and Mailpit web UI were published only on Windows loopback for separate Tailscale Serve routes.

Before the issuer change, verified custom-format backups were created for the application and
Keycloak databases. A guarded, operator-approved transaction changed only the two matching
`external_identities.issuer` values from the exact legacy issuer to the exact new HTTPS issuer.
Source count, target count, and subject-conflict checks ran before the update. Historical revoked-
session and audit rows retained the issuer that produced them.

| Step | Physical and stack result |
| --- | --- |
| Tailnet membership | The Windows host and Samsung phone were online in the same two-device tailnet. |
| Stable name and HTTPS | Android MagicDNS resolved the Windows full name to its Tailscale address. Chrome loaded `/api/v1/health` with no certificate warning, and an independent OpenSSL client verified the exact hostname and public CA chain over TLS 1.3. The Tailscale machine page reported a valid certificate. |
| Private routing | `tailscale serve status` exposed the loopback edge on standard private HTTPS and the loopback-bound Mailpit UI on a separate private HTTPS port. Every route was labeled `tailnet only`; no Funnel/public route was configured. Docker continued to publish the edge and Mailpit only on `127.0.0.1`. |
| Alternate Wi-Fi | With the laptop and phone on a different Wi-Fi network, Android showed validated Wi-Fi-backed Tailscale VPN connectivity. MagicDNS ping returned three of three replies, and Android HTTPS requests returned `200` for both the app health endpoint and the private Mailpit UI/API. No IP edit, APK rebuild, or ADB reverse rule was used. |
| OIDC routing | External discovery used the exact new HTTPS issuer. From the backend container, discovery retained that issuer while token and JWKS endpoints used `http://keycloak:8080` on the Compose network. |
| In-place APK migration | Debug APK SHA-256 `1B650F5585FFEC5648C668E4277EC5E3ADDE583D028DBFE7298B31C6744A8531` was installed with `adb install -r`. The June 15 first-install timestamp and Usage Access permission were preserved; Accessibility remained disabled and unbound. |
| AppAuth and protected session | The stale legacy session entered the expected reauthentication screen. AppAuth opened the real Keycloak form on the private HTTPS origin, the same existing account signed in, and the browser redirected to LockdIn. `GET /api/v1/auth/session` returned `200`. |
| Account and history preservation | Post-login count checks found 2 accounts, 2 identities on only the new issuer, and 3 profiles. No duplicate account was provisioned. Existing dashboard history rendered on the phone. |
| Usage synchronization | The authenticated phone received `200` for `POST /api/v1/usage/events`; stored usage increased from 2,192 to 2,272 events and daily app aggregates from 164 to 171. |
| Token renewal | The realm access-token lifetime was 300 seconds. At 514 seconds after the initial protected-session request, the phone made successful protected usage and dashboard requests without another provider sign-in, establishing fresh access-token renewal. |
| USB independence | ADB reported no connected device after the cable was physically unplugged. The phone then received `200` for protected usage upload and dashboard requests through Tailscale, with no reverse rule. |

The phone's Wi-Fi-to-mobile-data transition is intentionally deferred and is not claimed by this
run. A machine reboot was not performed. Two automated Windows service-restart attempts were denied
by the service ACL before the service could stop, so restart persistence is also not claimed;
Tailscale remained running and the background Serve route and trusted HTTPS health response remained
available after those denied attempts. This remains a private thesis prototype: every client must
join the tailnet, and the Windows host, Docker stack, and Tailscale must stay available.

## Manual Live-Queue Sync Automated Validation -- August 10, 2026

The native Accessibility uploader intentionally processes at most 15 queued rows per drain. Manual
**Sync Recent Usage** now repeats successful native drains until the signed-in account's queue is
empty, an upload fails, a drain makes no progress, or the 20-drain/300-upload safety limit is
reached. Tests cover a 35-row queue drained in three calls, a genuine network failure, a no-progress
response, and a continuously growing queue stopped after exactly 20 calls with an honest remaining-
work message.

The complete Flutter suite passed with 77 tests, Flutter analysis reported no issues, and the
backend suite remained at 142 passed with 3 expected skips. Fresh debug APK SHA-256
`D064BEA97EECEFA74EB0ED179BD3E13342CF3BBD4D6D4313EBD695C444744E89` built successfully and was
installed in place with `adb install -r`. The installed APK hash matched, the June 15 first-install
timestamp and both Usage Access and Accessibility remained intact, and no ADB reverse rule was
present. One-tap draining of multiple real 15-row chunks, the resulting dashboard refresh, and
duplicate-count checks remain physical verification items and are not claimed here.

The user then manually deleted the current account and created a new one. The new dashboard showed
zero for Today's Screen Time, and **Sync Recent Usage** truthfully reported that no Android usage
sessions were available yet; it did not import the prior account's history or report a backend
failure. A read-only, identifier-free database check found two short raw intervals owned by the
newest account but zero completed app/category aggregate minutes, consistent with the dashboard's
whole-minute display. This physically verifies account-scoped history isolation, but not the
multi-batch drain because the new account had no pending live queue to drain.

The user then generated new foreground usage and confirmed that Today's Screen Time began
accumulating for the new account. An identifier-free database check corroborated seven raw events
and two completed minutes in both app and category aggregates for the newest account. This verifies
that isolation did not prevent new account-owned usage from being recorded and displayed.

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
