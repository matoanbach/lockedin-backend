# LockdIn

LockdIn is an Android-focused digital-wellbeing prototype that helps users understand app usage,
set daily time limits, and receive soft interventions when limits are reached.

The system combines:

- a Flutter client for onboarding, dashboard, rules, trends, settings, and accountability;
- native Kotlin for Android UsageStats, Accessibility events, local retry state, and interventions;
- a FastAPI modular-monolith backend for validation, business logic, and analytics;
- PostgreSQL for raw usage events, rules, preferences, contacts, enforcement events, and daily
  aggregates.

The current build is designed for local development, testing, and academic evaluation. It is not
yet hardened for public production use.

## Features

- Android app-usage synchronization with automatic and manual sync
- recovery of Android sessions finalized after an earlier query
- idempotent uploads using stable source event IDs
- live Accessibility tracking with UsageStats fallback
- cross-source interval subtraction to prevent double counting
- configurable per-app daily limits
- warning notifications and soft Accessibility-based interventions
- dashboard, trends, top-app, peak-window, and weekly-summary analytics
- accountability contact storage
- text-size, high-contrast, and large-tap-target preferences
- offline error messages, queued retry behavior, and aggregate rebuild support
- interactive Swagger/ReDoc API documentation and exportable OpenAPI JSON

## Current Scope

The backend uses one default development profile. There is currently:

- no login or password;
- no admin, user, or guest role separation;
- no outbound accountability email;
- no public-production security guarantee.

Evaluators do not need credentials. All current requests operate on the same seeded/default
profile. Keep the application on a trusted local/demo network.

## Documentation

| Document | Purpose |
| --- | --- |
| [Documentation Index](docs/README.md) | Entry point for all audiences |
| [User Guide](docs/USER_GUIDE.md) | Non-technical setup and usage |
| [Evaluator Demo Walkthrough](docs/DEMO_WALKTHROUGH.md) | Rehearsed live presentation steps |
| [Thesis Defense Guide](docs/THESIS_DEFENSE_GUIDE.md) | Architecture, trade-offs, algorithms, testing, and limitations |
| [Testing and Evidence](docs/TESTING.md) | Test layers, commands, physical-device evidence, and gaps |
| [API Reference](backend/docs/api.md) | Endpoints, parameters, requests, responses, validation, and errors |
| [Media Capture Checklist](docs/MEDIA_CAPTURE_CHECKLIST.md) | Real screenshot/video requirements and privacy checks |
| [Security Testing Plan](docs/security/security-testing-plan.md) | Security scope, cases, tools, and readiness work |
| [Backend Onboarding](backend/docs/index.md) | Backend architecture and maintenance guide |

When an older academic report differs from the current code, use the current source, generated
OpenAPI schema, and operational guides above as the implementation reference.

## Repository Layout

```text
lockedin-backend/
├── backend/                 FastAPI service, tests, and backend docs
├── database/                PostgreSQL schema and repeatable seed data
├── docs/                    Project, evaluator, QA, and thesis documents
├── frontend/flutter_app/    Flutter client and native Android integration
├── k8s/                     Kubernetes and Argo CD manifests
├── docker-compose.yml       Full local backend/PostgreSQL stack
└── Jenkinsfile              Container build and GHCR publication pipeline
```

## System Requirements

Required for the complete local stack:

- Git
- Docker Desktop with Docker Compose v2
- Flutter stable with a Dart SDK compatible with `^3.12.0`
- Android Studio, Android SDK/platform tools, and ADB
- JDK 17 or newer for Android builds
- an Android emulator or USB-debuggable physical Android device

Optional:

- Python 3.11+ to run the backend outside Docker
- GNU Make for the backend convenience commands
- PostgreSQL client tools for direct local inspection
- MkDocs dependencies, installed through `backend[dev]`, for the static backend guide

For physical-device testing, the phone and development computer must be on the same trusted
network unless a secure deployed backend is used.

## Environment Setup

### Backend

Create the local backend environment file:

```powershell
Copy-Item backend/.env.example backend/.env
```

Important defaults:

- backend: `http://127.0.0.1:8000`
- health: `http://127.0.0.1:8000/api/v1/health`
- PostgreSQL host port: `5433`
- database: `lockedin`

Development defaults are not production secrets. Change credentials and settings before any
non-local deployment.

### Frontend

Create the compile-time frontend configuration:

```powershell
Copy-Item frontend/flutter_app/.env.sample frontend/flutter_app/.env
```

Choose the correct backend address:

```text
# Android emulator
LOCKDIN_API_BASE_URL=http://10.0.2.2:8000

# Desktop/web on the backend host
LOCKDIN_API_BASE_URL=http://127.0.0.1:8000

# Physical phone: replace with the host's current Wi-Fi IPv4 address
LOCKDIN_API_BASE_URL=http://192.168.2.44:8000

# Deployed environment
LOCKDIN_API_BASE_URL=https://api.example.com
```

The physical-device example is not a fixed project address. Find the current Windows Wi-Fi IPv4
address with `ipconfig`.

## Quick Start

From the repository root:

```powershell
docker compose --env-file backend/.env up -d --build
Invoke-RestMethod http://127.0.0.1:8000/api/v1/health
Set-Location frontend/flutter_app
flutter pub get
flutter run --dart-define-from-file=.env
```

Expected health response:

```json
{
  "status": "ok",
  "service": "LockdIn Backend",
  "version": "0.1.0"
}
```

On Windows, Flutter plugins may require **Settings > System > For developers > Developer Mode**
so the toolchain can create symbolic links.

## Physical Android Setup

1. Start the full Docker stack.
2. Find the host's current Wi-Fi IPv4 address using `ipconfig`.
3. Put that address in `frontend/flutter_app/.env`.
4. Confirm the phone can reach `http://<host-ip>:8000/api/v1/health`.
5. Connect and authorize USB debugging.
6. Confirm the device:

   ```powershell
   adb devices -l
   ```

7. Run or build the app:

   ```powershell
   Set-Location frontend/flutter_app
   flutter run --dart-define-from-file=.env
   ```

Android permission changes must be performed or approved by the device owner. Usage Access enables
fallback collection; notifications and Accessibility are optional and should not be changed merely
to troubleshoot connectivity.

Debug Android builds permit cleartext HTTP for trusted local development. Release builds retain
Android's cleartext restriction and should use HTTPS.

## Common Commands

### Full stack

```powershell
# Start or rebuild without deleting data
docker compose --env-file backend/.env up -d --build

# View status and logs
docker compose --env-file backend/.env ps
docker compose --env-file backend/.env logs -f backend

# Stop containers while preserving the database volume
docker compose --env-file backend/.env down
```

### Backend outside Docker

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
cd backend
make install-venv
make init-env
make run
```

### Tests

```bash
cd backend
make test
make test-postgres
```

```bash
cd frontend/flutter_app
flutter analyze
flutter test --coverage
dart format --set-exit-if-changed .
```

```powershell
Set-Location frontend/flutter_app/android
.\gradlew.bat testDebugUnitTest
```

### Builds

```bash
cd frontend/flutter_app
flutter build apk --debug --dart-define-from-file=.env
flutter build windows --debug --dart-define-from-file=.env
```

The Android release configuration currently uses debug signing and is not suitable for store
distribution.

### API and documentation

```bash
cd backend
make export-openapi
make build-docs
make docs-serve
```

Local documentation URLs:

- Swagger UI: `http://127.0.0.1:8000/api/docs`
- ReDoc: `http://127.0.0.1:8000/api/redoc`
- live OpenAPI JSON: `http://127.0.0.1:8000/openapi.json`
- built static backend guide: `http://127.0.0.1:8000/docs/`
- MkDocs development server: `http://127.0.0.1:9001`

Import `backend/docs/openapi.json` into Postman when an exportable collection is needed.

## Production-Oriented Deployment

The repository contains Docker, Kubernetes, Argo CD, GitHub Actions, and Jenkins/GHCR assets.
These demonstrate deployment structure, but do not by themselves make the system production-ready.

The checked-in Kubernetes secrets contain empty/template values, the ingress has no TLS host, and
the Argo CD application syncs only `k8s/backend`. Do not apply these manifests unchanged to a real
environment or commit real credentials into them.

Useful inspection commands after an operator has prepared a namespace, database, secrets, image,
DNS, and TLS:

```bash
kubectl -n lockedin get deployments,pods,services,ingresses,pvc,jobs
kubectl -n lockedin rollout status deployment/lockedin-backend
kubectl -n lockedin logs deployment/lockedin-backend
kubectl -n lockedin port-forward service/lockedin-backend 8000:8000
```

Before public deployment:

1. add authentication and per-user authorization;
2. replace development credentials and manage secrets outside Git;
3. use HTTPS through a trusted ingress or reverse proxy;
4. disable debug behavior and make API-doc exposure an explicit decision;
5. use proper Android release signing;
6. add migrations, backup/restore procedures, readiness checks, monitoring, and alerting;
7. review CORS, rate limits, abuse controls, privacy retention, and dependency licenses;
8. run load, security, accessibility, and disaster-recovery tests.

## Usage Synchronization Design

Android retains event-level history for a limited time, so LockdIn queries at most the last three
days on first sync. The client stores two separate values:

- last successful sync time, used for the automatic-sync cooldown;
- completed-session watermark, used as the next UsageStats starting point.

The watermark advances only to the latest successfully uploaded completed session. If Android has
not yet published a stop event, a later sync can recover that session in full.

When Accessibility tracking is active, the live upload queue is the usage source and UsageStats
fallback pauses. When fallback resumes, every uploaded live interval in the time window is
subtracted across package boundaries. This prevents Android sources from assigning the same
transition time to different apps and double counting it.

## Demo Data

Fresh database initialization creates:

- one default development profile;
- a 180-minute default limit;
- Instagram, YouTube, and Spotify rules;
- a demo accountability contact;
- recent relative-date usage records;
- sample YouTube warning and blocked enforcement events.

The seed is repeatable and conflict-safe. Existing volumes may contain additional device data.
Prepare a separate demo environment instead of deleting a developer's active database.

## Data Safety

Rebuild derived aggregates without deleting accepted raw events:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/api/v1/usage/aggregates/rebuild
```

This endpoint rewrites derived aggregate rows and is currently unauthenticated. Use it only in a
controlled environment.

The following command is destructive because `-v` deletes the PostgreSQL volume and all LockdIn
data:

```powershell
docker compose --env-file backend/.env down -v
```

Never use a volume reset, database-row deletion, app-data clearing, or aggregate rebuild as routine
troubleshooting. Confirm the target, explain exactly what will change, and obtain approval first.

## Testing and CI

Backend CI runs pytest and a PostgreSQL bootstrap smoke test. Frontend CI runs analysis,
formatting, Flutter tests with coverage generation, and Android/Windows debug builds. Native JUnit
tests cover Android usage reconstruction.

Physical Android regression testing has covered delayed stop events, Back navigation,
Picture-in-Picture, screen lock/unlock, backend offline/reconnect, rapid switching, Accessibility
live tracking, and transition back to UsageStats. See [Testing and Evidence](docs/TESTING.md).

The repository does not currently enforce a numeric coverage threshold. The July 25, 2026 local
Flutter report measured 603/3,609 lines (16.71%); backend percentage coverage was not measured.
Treat this as explicit test debt, not evidence that the older SRS target was achieved.

## Known Limitations

- single default profile and no authentication/roles;
- local/demo deployment posture;
- no accountability email delivery;
- soft enforcement can be bypassed through Android controls;
- no iOS usage collector;
- limited OEM, work-profile, multi-user, and split-screen validation;
- no full automated cross-stack UI test suite;
- no verified performance/load target;
- release build uses debug signing;
- schema changes require coordinated SQL and ORM updates; no migration framework yet;
- unknown apps may remain in the `Other` analytics category;
- no top-level project license has been selected.

See the [Thesis Defense Guide](docs/THESIS_DEFENSE_GUIDE.md) for rationale, trade-offs, and
recommended future work.
