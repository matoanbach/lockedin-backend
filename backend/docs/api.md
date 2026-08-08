# API Reference

This page documents the API implemented by the current backend. Runtime behavior and the generated
OpenAPI schema remain the source of truth.

## Interactive and Exportable References

With the backend running locally:

- Swagger UI: `http://127.0.0.1:8000/api/docs`
- ReDoc: `http://127.0.0.1:8000/api/redoc`
- OpenAPI JSON: `http://127.0.0.1:8000/openapi.json`
- Static backend guide: `http://127.0.0.1:8000/docs/`

Export a versioned OpenAPI file from the code:

```bash
cd backend
make export-openapi
```

The output is `backend/docs/openapi.json`. Postman can import either that file or the running
`/openapi.json` URL.

## Conventions

| Item | Current behavior |
| --- | --- |
| API base path | `/api/v1` |
| Content type | `application/json` |
| Field naming | camelCase over HTTP; snake_case internally |
| Authentication | HTTP bearer; every protected request is introspected by the configured Keycloak client |
| Identity | Protected routes require a server-derived `CurrentPrincipal` |
| Query parameters | None in the current API |
| Validation errors | HTTP `422` with FastAPI/Pydantic error details |
| Application errors | JSON shaped as `{"detail": "message"}` |

Phase C validates the exact issuer, restrictive `lockdin-api` audience, `lockdin-mobile` authorized
party, RS256 header, verified email, required session claims, token times, account status, account
not-before boundary, and local `sid` revocations. Missing or rejected credentials return a generic
`401`; unavailable or ambiguous provider state returns a generic `503`. The separate operator
dependency remains fail-closed with `403`.

The evidence-backed current exposure inventory and proposed public/protected/internal
classification are in the
[Authentication, Session, and Tenant-Isolation ADR](decisions/authentication-session-tenant-isolation.md).
The generated OpenAPI document contains the `KeycloakAccessToken` HTTP bearer scheme. This is not
evidence that a physical phone trusts the local CA or that the Flutter Phase D login exists.

## Endpoint Summary

Authentication endpoints:

| Method | Path | Purpose | Success | Other responses |
| --- | --- | --- | --- | --- |
| `GET` | `/api/v1/auth/config` | Public native OIDC bootstrap, with no secret | `200` | - |
| `GET` | `/api/v1/auth/session` | Resolve the authenticated account/session | `200` | `401`, `503` |
| `POST` | `/api/v1/auth/logout` | Revoke the current provider/local session | `204` | `401` |
| `POST` | `/api/v1/auth/logout-all` | Advance the account boundary and terminate provider sessions | `204` | `401`, `503` |
| `POST` | `/api/v1/auth/backchannel-logout` | Verify an OIDC logout token and revoke it replay-safely | `204` | `400`, `503` |
| `POST` | `/api/v1/auth/provider-events` | Verify an internal HMAC provider event | `204` | `400`, `503` |

| Method | Path | Request | Success | Other documented responses |
| --- | --- | --- | --- | --- |
| `GET` | `/` | None | `200` service message | — |
| `GET` | `/api/v1/health` | None | `200` health payload | — |
| `GET` | `/api/v1/rules` | None | `200` rule list | — |
| `GET` | `/api/v1/rules/status` | None | `200` computed rule statuses | — |
| `POST` | `/api/v1/rules` | `RuleCreate` | `201` rule | `409`, `422` |
| `PATCH` | `/api/v1/rules/{rule_id}` | `RuleUpdate` | `200` rule | `404`, `422` |
| `DELETE` | `/api/v1/rules/{rule_id}` | None | `204` | `404`, `422` |
| `POST` | `/api/v1/usage/events` | `UsageIngestionRequest` | `200` counts | `409`, `422` |
| `POST` | `/api/v1/usage/aggregates/rebuild` | None | `200` counts | `403` without internal operator scope |
| `GET` | `/api/v1/analytics/dashboard` | None | `200` dashboard metrics | — |
| `GET` | `/api/v1/analytics/trends` | None | `200` trend metrics | — |
| `GET` | `/api/v1/analytics/weekly-summary` | None | `200` weekly summary | — |
| `POST` | `/api/v1/enforcement/events` | `EnforcementEventCreate` | `201` event | `404`, `422` |
| `GET` | `/api/v1/accountability/contacts` | None | `200` contact list | — |
| `POST` | `/api/v1/accountability/contacts` | `AccountabilityContactCreate` | `201` contact | `409`, `422` |
| `DELETE` | `/api/v1/accountability/contacts/{contact_id}` | None | `204` | `404`, `422` |
| `GET` | `/api/v1/me/preferences` | None | `200` preferences | — |
| `PUT` | `/api/v1/me/preferences` | `PreferencesUpdate` | `200` preferences | `422` |

`rule_id` and `contact_id` are string identifiers supplied as path parameters.

## Root and Health

### `GET /`

Example response:

```json
{
  "message": "LockdIn Backend is running"
}
```

### `GET /api/v1/health`

Example response:

```json
{
  "status": "ok",
  "service": "LockdIn Backend",
  "version": "0.1.0"
}
```

This is a liveness check only. It does not verify PostgreSQL connectivity.

## Rules

### Rule object

```json
{
  "id": "00000000-0000-0000-0000-000000000102",
  "appId": "com.google.android.youtube",
  "appName": "YouTube",
  "limitMinutes": 45,
  "enabled": true
}
```

### `GET /api/v1/rules`

Returns an array of rule objects.

### `GET /api/v1/rules/status`

Returns computed usage status for each rule:

```json
[
  {
    "ruleId": "00000000-0000-0000-0000-000000000102",
    "appId": "com.google.android.youtube",
    "appName": "YouTube",
    "usageDate": "2026-07-25",
    "enabled": true,
    "limitMinutes": 45,
    "usedMinutes": 38,
    "remainingMinutes": 7,
    "progressPercent": 84,
    "status": "approaching_limit",
    "isBlockedNow": false
  }
]
```

Values depend on current data; the example shows the response shape.

### `POST /api/v1/rules`

Required fields are `appId`, `appName`, and a positive `limitMinutes`. `enabled` defaults to `true`.

```bash
curl -X POST http://127.0.0.1:8000/api/v1/rules \
  -H "Content-Type: application/json" \
  -d '{
    "appId": "com.example.reading",
    "appName": "Reading App",
    "limitMinutes": 30,
    "enabled": true
  }'
```

Returns `409` if the principal's profile already has a rule for the canonicalized app ID.

### `PATCH /api/v1/rules/{rule_id}`

All body fields are optional, but supplied values must remain valid:

```json
{
  "limitMinutes": 60,
  "enabled": false
}
```

Returns `404` when the rule does not exist.

### `DELETE /api/v1/rules/{rule_id}`

Returns `204` with no response body, or `404` when the rule does not exist.

## Usage Events

### `POST /api/v1/usage/events`

Replace the example timestamps with a current interval before executing it; events older than
90 days are rejected.

Example request:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/usage/events \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {
        "sourceEventId": "demo:reading:2026-07-25T14:00:00Z",
        "appId": "com.example.reading",
        "appName": "Reading App",
        "category": "Productivity",
        "startedAt": "2026-07-25T14:00:00Z",
        "endedAt": "2026-07-25T14:20:00Z",
        "timezone": "America/Toronto"
      }
    ]
  }'
```

Example response:

```json
{
  "receivedCount": 1,
  "createdCount": 1,
  "duplicateCount": 0
}
```

Validation and integrity rules:

- 1–100 events per request
- encoded request model no larger than 128 KiB
- required strings cannot be blank
- `sourceEventId`, `appId`, and `appName` are limited to 255 characters
- `category` is optional and limited to 100 characters
- `timezone` must be a valid IANA time-zone name
- timestamps must include UTC offsets
- `endedAt` must be later than `startedAt`
- one event may not exceed six hours
- an event may not be older than 90 days
- timestamps may not be more than five minutes in the future
- distinct events for the same app may not overlap within one request
- an event may not overlap an already stored event for the same app
- replaying an existing `sourceEventId` is idempotent and increments `duplicateCount`
- stored-overlap conflicts return `409`

The backend calculates persisted duration from the timestamps; clients do not submit a duration.

### `POST /api/v1/usage/aggregates/rebuild`

Recalculates daily app and category aggregates from accepted raw usage events.

```json
{
  "eventCount": 42,
  "appAggregateCount": 12,
  "categoryAggregateCount": 8
}
```

This endpoint does not delete raw usage events, but it rewrites derived aggregate rows. It is on a
separate operator router. The default Phase B operator dependency returns `403`; only tests can
override it with a trusted, profile-scoped `OperatorPrincipal`. A deployable operator mechanism is
still pending.

## Analytics

### `GET /api/v1/analytics/dashboard`

```json
{
  "todayTotalMinutes": 120,
  "categoryBreakdown": [
    {
      "name": "Video & Entertainment",
      "minutes": 60,
      "durationMilliseconds": 3600000
    }
  ],
  "weeklyUsageHours": [1.0, 0.5, 2.0, 1.25, 0.75, 0.0, 2.0],
  "weeklyTotalMinutes": 450,
  "deltaFromYesterdayPercent": -10
}
```

### `GET /api/v1/analytics/trends`

```json
{
  "hourlyUsage": [
    {
      "hour": "14:00",
      "minutes": 20
    }
  ],
  "weeklyUsage": [
    {
      "day": "Fri",
      "hours": 2.0
    }
  ],
  "weeklyTotalMinutes": 510,
  "topApps": [
    {
      "appId": "com.google.android.youtube",
      "appName": "YouTube",
      "minutes": 55
    }
  ],
  "peakUsageWindow": "7 PM - 9 PM"
}
```

### `GET /api/v1/analytics/weekly-summary`

```json
{
  "screenTimeReductionPercent": 10,
  "totalWeekHours": 8.5,
  "dailyAverageHours": 1.2,
  "goalsMetDays": 5,
  "longestStreakDays": 3
}
```

Analytics examples show shapes, not guaranteed seeded values. Daily chart hours are independently
rounded to one decimal for plotting. `weeklyTotalMinutes` is calculated from the exact summed raw
duration and is the authoritative completed-minute headline total; clients should not sum the
rounded chart values for that purpose.

Dashboard categories and Trends app names use a package-based descriptive taxonomy at analytics
read time. Known package IDs receive stable display names and categories. Unknown packages retain
useful stored names and categories, with the package ID and `Other` used only when stored metadata
is blank. This taxonomy describes app types; it does not measure whether usage is productive.
`durationMilliseconds` preserves positive sub-minute category duration while `minutes` continues
to report completed minutes.

## Enforcement

### `POST /api/v1/enforcement/events`

Allowed `eventType` values:

- `warning_approaching_limit`
- `warning_limit_reached`
- `intervention_blocked`
- `intervention_dismissed`

Request:

```json
{
  "ruleId": "00000000-0000-0000-0000-000000000102",
  "appId": "com.google.android.youtube",
  "eventType": "warning_approaching_limit",
  "usageDate": "2026-07-25",
  "usedMinutes": 38,
  "limitMinutes": 45,
  "metadata": {
    "source": "demo"
  }
}
```

`ruleId` and `metadata` are optional. `usedMinutes` must be zero or greater and `limitMinutes` must
be positive. A supplied but unknown rule ID returns `404`.

## Accountability Contacts

### Contact object

```json
{
  "id": "00000000-0000-0000-0000-000000000201",
  "name": "Demo Accountability Partner",
  "email": "partner@example.com",
  "consentConfirmed": true
}
```

### `GET /api/v1/accountability/contacts`

Returns contacts associated with the principal's server-derived profile.

### `POST /api/v1/accountability/contacts`

```json
{
  "email": "reviewer@example.com",
  "name": "Demo Reviewer",
  "consentConfirmed": true
}
```

`email` must be valid. `name` is optional. A duplicate normalized email returns `409`.

### `DELETE /api/v1/accountability/contacts/{contact_id}`

Returns `204`, or `404` when the contact does not exist.

## Preferences

### `GET /api/v1/me/preferences`

```json
{
  "hasCompletedOnboarding": true,
  "defaultDailyLimitMinutes": 180,
  "notificationTone": "professional",
  "accessibility": {
    "textSizePercent": 100,
    "highContrast": false,
    "largeTapTargets": false
  }
}
```

### `PUT /api/v1/me/preferences`

This is a partial update even though the method is `PUT`; omitted values remain unchanged.

```json
{
  "notificationTone": "professional",
  "textSizePercent": 120,
  "highContrast": true,
  "largeTapTargets": true
}
```

Constraints:

- `defaultDailyLimitMinutes` must be positive
- `notificationTone`: `fun`, `edgy`, or `professional`
- `textSizePercent`: 80–150

## Error Examples

Validation error (`422`):

```json
{
  "detail": [
    {
      "type": "greater_than",
      "loc": ["body", "limitMinutes"],
      "msg": "Input should be greater than 0",
      "input": 0
    }
  ]
}
```

Application conflict (`409`):

```json
{
  "detail": "Rule already exists for app_id 'com.google.android.youtube'"
}
```

Not found (`404`):

```json
{
  "detail": "Rule 'missing-id' was not found"
}
```

Exact Pydantic validation details can vary by dependency version; clients should rely on the HTTP
status and `detail` field rather than matching complete error text.

## API Change Checklist

When changing the API:

1. Update route, schema, service, repository, and database definitions as applicable.
2. Add or update backend tests.
3. Run `make test` and, for persistence changes, `make test-postgres`.
4. Run `make export-openapi`.
5. Review the OpenAPI diff and this page.
6. Verify Swagger UI against a running local stack.
