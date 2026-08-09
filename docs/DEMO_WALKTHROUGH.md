# Evaluator Demo Walkthrough

This runbook is designed for a 7–10 minute live demonstration. Rehearse it using the same device,
network, database, and build planned for the evaluation.

The Phase D source connects Flutter to the Phase C backend boundary with AppAuth PKCE, secure
storage, guarded routes, renewal, logout, and account-owned queues. Automated tests and a debug APK
build pass. An isolated August 8 physical-phone run also verified CA trust, registration and normal
sign-in pages, Mailpit verification delivery, redirect, token exchange/introspection, protected
session bootstrap, authenticated onboarding, and local sign-out persistence. Rehearse with a fresh
disposable identity before presenting this as a live login demo; no reusable evaluator credential
is stored in this repository.

## Demo Identity and Roles

The Phase A demo build has no login or account roles. The Phase D client has physically verified
local/demo login integration, but the evidence set intentionally contains no reusable evaluator
credentials.

| Demo identity | Credentials | Effective access |
| --- | --- | --- |
| Phase A default development profile | None | Behavioral demo functions in the approved Phase A build only |

Do not advertise admin/user role differences. Explain that the demonstrated Phase A build focused
on usage reconstruction, rules, analytics, and Android enforcement. Phase C establishes backend
authentication; Phase D implements the mobile lifecycle and has controlled isolated physical proof
for fresh sign-in and sign-out.

## Preparation Checklist

Complete this before the audience arrives:

- [ ] Use the latest approved commit and record its hash.
- [ ] Start Docker Desktop.
- [ ] Start the full stack without deleting its volume.
- [ ] Confirm PostgreSQL and backend report healthy.
- [ ] Confirm `GET /api/v1/health` returns `200`.
- [ ] Confirm Swagger UI opens at `/api/docs`.
- [ ] Confirm the phone and host are on the same trusted Wi-Fi.
- [ ] Confirm the compiled `LOCKDIN_API_BASE_URL` uses the host's current IPv4 address.
- [ ] If using the approved Phase A demo build, open LockdIn and confirm the dashboard loads.
- [ ] Confirm Usage Access is in the planned state.
- [ ] Confirm notification and Accessibility states match the planned script.
- [ ] Load only seeded or synthetic data.
- [ ] Disable personal notifications and close unrelated applications.
- [ ] Keep a local APK and screenshots as fallback evidence.
- [ ] Do not reset the database immediately before the presentation.

Useful host checks:

```powershell
docker compose --env-file backend/.env ps
Invoke-RestMethod http://127.0.0.1:8000/api/v1/health
git rev-parse --short HEAD
```

## Realistic Seed Data

The database bootstrap creates:

- one development profile;
- preferences with a 180-minute default daily limit;
- Instagram, YouTube, and Spotify rules;
- one demo accountability partner;
- seven recent usage events across Social and Entertainment categories;
- warning and blocked enforcement examples for YouTube.

Seeded dates are calculated relative to database initialization, so charts remain recent. Existing
development volumes may contain additional physical-device data. For a formal demo, use a separate
prepared demo volume rather than deleting a developer's volume.

## Main Walkthrough

### 1. Problem and architecture — 45 seconds

Say:

> LockdIn helps a user understand Android app usage, set daily limits, and receive a soft
> intervention when a limit is reached. The Flutter Android client collects device events, the
> FastAPI modular monolith validates and processes them, and PostgreSQL stores raw events and
> derived daily analytics.

Show the dashboard and briefly identify the client/backend interaction.

### 2. Dashboard and realistic data — 60 seconds

1. Show today's total, category breakdown, and weekly chart.
2. Explain that seeded data makes the evaluation repeatable.
3. Point out that dashboard totals come from backend aggregates, not hard-coded UI values.

Expected result on the approved Phase A demo build: dashboard loads without a spinner or error.
For Phase D, the expected flow is system-browser sign-in followed by guarded onboarding/dashboard,
but use it live only after the exact realm, redirect, TLS trust, and test credentials are verified.

### 3. Usage synchronization — 90 seconds

1. Confirm Android Usage Access was already granted by the device owner.
2. Tap **Sync Recent Usage**.
3. Read the collected, created, and duplicate counts.
4. Tap sync once more if time allows.

Explain:

- a repeated source ID is treated as a duplicate, not inserted again;
- a successful sync watermark advances only to the latest completed session;
- unfinished Android sessions can be recovered later;
- Accessibility live intervals are subtracted globally from UsageStats fallback intervals.

Expected result: the second sync normally creates zero new rows.

### 4. Rules and enforcement — 90 seconds

1. Open **Rules**.
2. Show the seeded YouTube rule.
3. Change its limit or enabled state.
4. Return to the dashboard and show the computed rule status.

Explain that enforcement is soft because Android users retain control over Accessibility and can
force-stop or reconfigure applications.

### 5. Trends and weekly summary — 60 seconds

1. Open **Trends**.
2. Show hourly usage, weekly usage, top apps, and peak window.
3. Open **Weekly Summary**.
4. Show total time, average, goals, and streaks.

Explain that daily aggregates speed common dashboard queries while raw events remain the source
for rebuilding derived data.

### 6. Accountability — 45 seconds

1. Open **Accountability**.
2. Show the seeded demo contact.
3. Explain consent and privacy.

Do not claim that email delivery exists. The current feature stores and removes contacts only.

### 7. API transparency — 45 seconds

Open `http://127.0.0.1:8000/api/docs` on the host.

1. Show endpoint groups.
2. Expand `GET /api/v1/health`.
3. Execute it and show the `200` response.
4. Mention that `/openapi.json` is committed/exportable for Postman import.

## Edge-Case Demonstrations

Choose one live edge case and keep the rest as prepared evidence.

### Invalid input

Try to create a rule with a non-positive limit or submit an invalid contact email.

Expected result: the client prevents submission or shows a clear error; direct invalid API payloads
return `422`.

### Duplicate rule

Attempt to create a second rule for an app already configured.

Expected result: backend returns `409`; no second rule is stored.

### Duplicate usage upload

Submit the same `sourceEventId` twice through Swagger.

Expected result: first request creates it, second increments `duplicateCount`; aggregates do not
double.

### Backend unavailable

Use a pre-recorded clip or stop only the backend container during a controlled rehearsal. Do not
stop PostgreSQL or delete volumes.

Expected result: LockdIn displays the configured backend URL and a connection message. Restoring
the backend allows queued/recent usage to synchronize without advancing a failed watermark.

### Invalid time interval

Through Swagger, submit an event whose `endedAt` is earlier than `startedAt`.

Expected result: `422`, no database write.

## Failure-Proof Presentation Plan

| Failure | Recovery |
| --- | --- |
| Phone cannot reach host | Show health locally, verify host IPv4/firewall, then use screenshots |
| Docker build is slow | Start containers before the presentation |
| Usage sync has no new events | Explain that automatic sync already completed; show counts and DB/API evidence |
| Android permission dialog changes | Do not improvise; use the prepared permission-state screenshot |
| Physical device disconnects | Continue with Swagger, seeded dashboard screenshots, and recorded video |
| Personal data appears | Stop sharing immediately and switch to sanitized media |

## Closing Statement

End with:

> The prototype demonstrates reliable usage ingestion, idempotent synchronization, rules,
> analytics, accessible display options, and Android soft enforcement. Phase B adds fail-closed
> tenant and infrastructure foundations, and Phase D implements the mobile authentication lifecycle
> with automated/build evidence plus isolated physical proof of AppAuth registration/sign-in, TLS
> trust, Mailpit verification delivery, protected-session bootstrap, and local sign-out persistence.
> Successful long-offline renewal, real SQLite migration, formal usability research, release
> signing, and stronger operations remain explicit next steps.
