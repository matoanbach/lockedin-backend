# Phase 4: Rule Evaluation And Enforcement

## Priority

Phase 4 is the next major product phase after real usage ingestion and analytics are in place.

This phase remains high priority because it turns LockdIn from a passive analytics app into a product that can actively help a user stop when they exceed a limit.

## Objective

Build the first real rule-enforcement loop for LockdIn on Android.

By the end of Phase 4:
- saved rules should be evaluated against real synced usage
- the app should be able to show per-rule progress and over-limit state
- the app should be able to warn the user as they approach or exceed limits
- Android should support a first accessibility-backed intervention flow for over-limit apps
- the backend and frontend should share a stable contract for rule status and enforcement state

## Scope

Included in Phase 4:
- backend rule evaluation logic
- backend rule status endpoint
- backend support for enforcement and warning event logging
- frontend rule progress UI
- Android warning flow
- Android accessibility-backed intervention flow
- tests for rule evaluation and enforcement contract behavior

Not included in Phase 4:
- iOS enforcement
- full real-time continuous monitoring service
- accountability auto-notifications
- email or SMS delivery
- auth
- Supabase integration
- advanced scheduling and exceptions
- category-based rules
- cross-device synchronization semantics beyond the current single local backend setup

## Phase Direction

Phase 4 is the first intentionally full-stack product phase.

Important context:
- Phase 2 already made rules persistent
- Phase 3 already made usage ingestion and analytics real
- the Android app can now sync recent usage sessions into the backend
- rules still do not do anything active yet

That means Phase 4 should focus on:
- turning saved rules into evaluated rule state
- surfacing that state clearly in the app
- using that state to drive Android warnings and intervention

Implementation direction:
- Python backend
- FastAPI monolith
- SQLite for local development
- Android-first enforcement behavior
- one implicit development profile still scopes data internally
- backend remains the source of truth for rule state

## Product Direction

Phase 4 should make a user feel a direct connection between:
- a saved rule such as `YouTube -> 10 minutes`
- actual tracked usage
- a visible response once the threshold is reached

That means the first Phase 4 user journey should be:
1. create or edit a rule
2. use the target app on Android
3. sync usage automatically or manually
4. see progress toward the limit
5. receive a warning near or at the threshold
6. encounter intervention when trying to keep using the app past the limit

## Rule Semantics

Phase 4 should keep rule semantics simple and explicit.

For the MVP:
- rules remain per-app only
- only enabled rules participate in evaluation
- evaluation window is the current local day in the device timezone
- used minutes come from backend-owned Phase 3 daily app aggregates
- the limit comparison is `used_minutes >= limit_minutes`

Important behavior decisions:
- usage tracking does not require a rule to exist
- a rule does not alter analytics totals
- a rule only changes how the app interprets and responds to existing tracked usage

Rule states should be defined as:
- `under_limit`
- `approaching_limit`
- `at_limit`
- `over_limit`

Suggested initial threshold logic:
- `approaching_limit` when `used_minutes >= 0.8 * limit_minutes`
- `at_limit` when `used_minutes == limit_minutes`
- `over_limit` when `used_minutes > limit_minutes`

## Warning And Intervention Model

Phase 4 should separate warnings from blocking.

Warnings:
- are lightweight and local
- should happen before or at the limit
- can be shown through local notifications and visible rule progress UI

Intervention:
- is stronger and Android-specific
- should happen when a user opens or stays in an app that is already over limit
- should rely on Accessibility for the first implementation

Important MVP decision:
- Phase 4 should not try to build a perfect OS-level blocker immediately
- instead, build a reliable intervention loop:
  - detect the current foreground package through Accessibility
  - compare it against backend-evaluated over-limit rules
  - show a LockdIn interruption screen or redirect flow

That gets the core product loop working without pretending the app can fully hard-block every Android scenario on the first pass.

## Ownership And Source Of Truth

Auth is still deferred.

Phase 4 continues using the same temporary ownership model:
- one implicit development profile
- rules, usage, warnings, and enforcement events are all scoped to that profile internally

Source-of-truth decisions:
- backend usage aggregates remain the source of truth for `used_minutes`
- backend rule evaluation remains the source of truth for current rule state
- Android foreground detection is the source of truth for whether intervention should fire at this moment

## Deliverables

Phase 4 is complete when the project has:
- backend rule evaluation service
- backend rule status endpoint
- frontend rules UI showing progress and status
- local warning behavior for approaching and exceeded limits
- Android accessibility-backed intervention flow for over-limit apps
- persistence for enforcement-related audit events
- tests covering evaluation, status responses, and enforcement event flows

## Planned Modules

### 1. Rule Evaluation Module

Purpose:
- compute current rule status from saved rules and tracked usage

What it should support now:
- read all enabled app rules for the default profile
- join or compare those rules against current local-day app usage
- compute used minutes, remaining minutes, progress percent, and status
- support zero-usage and zero-rule states cleanly

Suggested backend result per rule:
- `ruleId`
- `appId`
- `appName`
- `limitMinutes`
- `usedMinutes`
- `remainingMinutes`
- `progressPercent`
- `status`
- `isBlockedNow`

Expected result:
- the app can render meaningful rule state without reimplementing business logic on-device

### 2. Rule Status API Module

Purpose:
- expose evaluated rule state to the frontend and Android enforcement layer

Suggested first endpoints:
- `GET /api/v1/rules/status`
- `GET /api/v1/rules/status/{rule_id}`

What it should return now:
- evaluated status for all rules or a single rule
- enough data to render progress bars and warnings

Expected result:
- frontend and Android enforcement code can consume the same stable contract

### 3. Enforcement Event Module

Purpose:
- log warning and intervention actions for debugging, UX, and future accountability hooks

What it should support now:
- record a warning event when the user is notified near or at the limit
- record an intervention event when the user is interrupted for an over-limit app
- store minimal device or platform metadata where useful

Suggested event types:
- `warning_approaching_limit`
- `warning_limit_reached`
- `intervention_blocked`
- `intervention_dismissed`
- `intervention_override_requested` later

Expected result:
- the product has a minimal audit trail for enforcement behavior

### 4. Frontend Rule Progress Module

Purpose:
- show how rules relate to actual usage

What it should support now:
- progress bars per rule
- `used / limit` display
- clear status badges such as `Approaching`, `At Limit`, `Over Limit`
- refresh from backend after sync

Expected result:
- the rules screen stops being just configuration and becomes a live control panel

### 5. Warning Module

Purpose:
- alert the user before or when they cross a limit

What it should support now:
- local notification or in-app warning behavior on Android
- deduplicate repeated warnings during the same day or same threshold window
- refresh warning eligibility after a new local day begins

Implementation note:
- for the MVP, warnings can be triggered from app-open, app-resume, and explicit sync moments
- true continuous warning evaluation is not required yet

Expected result:
- the user receives timely nudges without needing full blocking to exist first

### 6. Android Intervention Module

Purpose:
- interrupt usage of over-limit apps on Android

What it should support now:
- detect the foreground app through Accessibility
- ask the backend or local cached rule state whether that app is over limit
- show an intervention screen when the app is over limit
- let the user leave the target app and return to LockdIn or home

Implementation note:
- Phase 4 should prefer a LockdIn-hosted intervention experience over trying to silently kill or fully lock apps
- keep the first version understandable and debuggable

Expected result:
- users experience a real consequence when continuing past a saved limit

## Proposed Tables

### `enforcement_events`

Purpose:
- log warning and intervention actions taken by the product

Suggested fields:
- `id`
- `profile_id`
- `rule_id`
- `app_id`
- `event_type`
- `usage_date`
- `used_minutes`
- `limit_minutes`
- `metadata_json` or a small text payload
- `created_at`

Suggested notes:
- `rule_id` can be nullable if a warning is emitted from a derived rule status path that later evolves
- keep this table append-only in the MVP

Suggested indexes:
- index on `profile_id + usage_date`
- index on `profile_id + rule_id + created_at`

### Optional `rule_status_snapshots`

Purpose:
- only if Phase 4 needs persisted snapshots later

Recommendation:
- do not persist snapshots in the first implementation unless needed
- prefer computing rule status from rules plus daily app aggregates

Why:
- keeps the MVP simpler
- avoids stale derived state problems

## Suggested Request And Response Schemas

### Rule Status Response Example

```json
[
  {
    "ruleId": "rule_123",
    "appId": "com.google.android.youtube",
    "appName": "YouTube",
    "limitMinutes": 10,
    "usedMinutes": 14,
    "remainingMinutes": 0,
    "progressPercent": 140,
    "status": "over_limit",
    "isBlockedNow": true
  }
]
```

### Enforcement Event Create Example

```json
{
  "ruleId": "rule_123",
  "appId": "com.google.android.youtube",
  "eventType": "intervention_blocked",
  "usageDate": "2026-06-08",
  "usedMinutes": 14,
  "limitMinutes": 10,
  "metadata": {
    "source": "android_accessibility"
  }
}
```

## Analytics Contract Direction

Phase 4 should not replace Phase 3 analytics endpoints.

Instead, it should add rule-focused contracts that complement them.

General principles:
- keep using `/api/v1`
- keep camelCase responses
- prefer explicit rule-state fields over UI-formatted strings
- return stable empty states when no rules or no usage exist

Important behavior decision:
- if a rule exists but no usage has been synced for the current day, its status should still be returned with `usedMinutes = 0`
- if no rules exist, `GET /api/v1/rules/status` should return `[]`

## Android Direction

Phase 4 should remain Android-first.

Recommended Android behavior:
- continue using Phase 3 session sync as the usage source
- auto-sync on app open and app resume remains sufficient for the first enforcement pass
- Accessibility should be introduced for foreground app detection and intervention only

Important note:
- do not couple enforcement to a fully continuous background analytics pipeline yet
- keep the first version centered on real, understandable user flows

## Frontend Direction

Primary frontend consumers in Phase 4:
- `frontend/flutter_app/lib/features/rules/presentation/screens/lockdown_rules_screen.dart`
- `frontend/flutter_app/lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Android permission and intervention surfaces

Expected frontend changes:
- show rule progress from backend data
- show rule status badges
- surface `last synced at` and enforcement-relevant sync freshness
- show intervention UI when the current foreground app is over limit

## Step-By-Step Implementation Plan

### Step 1: Add Enforcement Event Model And Migration

Tasks:
- create `enforcement_event.py`
- register it in `models/__init__.py`
- add a Phase 4 Alembic migration
- keep the table minimal and append-only

Output:
- backend can persist warning and intervention audit events

### Step 2: Add Rule Evaluation Schemas And Service

Tasks:
- create rule status response schemas
- create enforcement event create schemas if needed
- add backend rule evaluation service logic
- define threshold and remaining-minute behavior clearly

Output:
- backend can compute rule state from rules and daily aggregates

### Step 3: Add Rule Status Routes

Tasks:
- add `GET /api/v1/rules/status`
- add `GET /api/v1/rules/status/{rule_id}` if needed
- keep behavior safe for no-rule and no-usage cases

Output:
- frontend and Android enforcement have a stable rule-status contract

### Step 4: Add Enforcement Event Routes Or Internal Logging Path

Tasks:
- decide whether Android writes enforcement events through an endpoint or whether the backend logs them as part of rule evaluation workflows
- prefer the smallest correct path
- ensure warning and intervention events can be recorded

Output:
- enforcement actions become inspectable and testable

### Step 5: Add Frontend Rule Progress UI

Tasks:
- fetch rule status data in the Flutter rules feature
- render used vs limit progress
- render status badges and over-limit styling
- keep existing CRUD flows intact

Output:
- rules screen becomes a live status screen instead of static configuration only

### Step 6: Add Android Warning Flow

Tasks:
- decide where warnings should fire from in the current architecture
- deduplicate warnings per threshold and local day
- show local notification or in-app warning when a rule is approaching or exceeded

Output:
- users are warned before or when crossing saved limits

### Step 7: Add Android Accessibility Intervention Flow

Tasks:
- add Accessibility permission detection and setup guidance
- detect the foreground app
- compare current foreground app against over-limit rule state
- show intervention UI when appropriate
- keep the intervention logic understandable and reversible

Output:
- the first real LockdIn enforcement behavior exists on Android

### Step 8: Add Tests

Tasks:
- add backend rule evaluation tests
- add backend rule status route tests
- add backend enforcement event persistence tests
- add Flutter tests for rule progress rendering where practical
- add Android-side verification steps or instrumentation notes for intervention behavior

Output:
- Phase 4 behavior is protected by automated coverage where feasible

## Suggested File Targets

Likely new or updated files:

```text
backend/PHASE4.md
backend/src/lockedin_backend/models/enforcement_event.py
backend/src/lockedin_backend/models/__init__.py
backend/src/lockedin_backend/schemas/rule_status.py
backend/src/lockedin_backend/schemas/enforcement.py
backend/src/lockedin_backend/repositories/enforcement_event_repository.py
backend/src/lockedin_backend/services/rule_status_service.py
backend/src/lockedin_backend/api/routes/rule_status.py
backend/alembic/versions/<phase4_revision>.py
backend/tests/test_rule_status.py
backend/tests/test_enforcement.py
frontend/flutter_app/lib/features/rules/data/rule_status_provider.dart
frontend/flutter_app/lib/features/rules/presentation/screens/lockdown_rules_screen.dart
frontend/flutter_app/android/app/src/main/kotlin/.../MainActivity.kt
frontend/flutter_app/android/app/src/main/kotlin/.../<accessibility_service>.kt
```

## Testing Plan

Minimum Phase 4 coverage should include:
- enabled rules with no usage return `under_limit` and `usedMinutes = 0`
- rule status reflects daily usage correctly
- `approaching_limit`, `at_limit`, and `over_limit` boundaries behave correctly
- disabled rules are excluded from active evaluation
- rule status route returns valid empty states
- enforcement events persist correctly
- Android warning and intervention flows do not crash when permissions are missing

Recommended testing emphasis:
1. rule evaluation correctness
2. boundary conditions around limit thresholds
3. empty-state response correctness
4. Android permission and intervention safety
5. event logging correctness

## Completion Criteria

Phase 4 is complete when:
- rules are evaluated against real usage data
- users can see per-rule progress and status in the app
- warnings can be emitted for limit thresholds
- Android intervention can trigger for over-limit apps
- enforcement actions can be inspected through persisted event logs
- tests cover the main success and boundary paths

## Out Of Scope

The following should not block Phase 4 completion:
- perfect hard blocking across every Android OEM
- iOS enforcement
- category rules
- scheduled quiet hours or exceptions
- accountability auto-messaging
- real-time continuous monitoring service
- auth and multi-user protection
- Supabase migration

## Open Questions

### 1. Should rule status be computed or persisted?

Recommendation:
- compute it on demand from rules plus daily aggregates

Why:
- simpler MVP
- avoids stale derived state
- Phase 3 aggregate reads are already fast enough for this scope

### 2. Should warnings come from the backend or Android locally?

Recommendation:
- evaluate rule state from backend data, but let Android trigger local warnings in the MVP

Why:
- no push infrastructure needed
- faster feedback loop
- fits the current no-auth local-backend setup

### 3. Should intervention be a true app block or a visible interruption first?

Recommendation:
- start with visible interruption first

Why:
- simpler and safer to ship
- easier to debug
- enough to prove the core product loop

### 4. Should app-open and app-resume sync be enough for the first enforcement pass?

Recommendation:
- no

Why:
- current usage freshness is good enough for analytics but not for live blocking
- a sync-only model cannot interrupt a user who remains inside the limited app
- Accessibility-backed real-time enforcement is required for the core LockdIn promise
