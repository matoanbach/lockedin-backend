# LockdIn

LockdIn is split into three local pieces:

- `frontend/flutter_app`: Flutter Android/Desktop app
- `backend`: FastAPI backend
- `database`: Postgres bootstrap and seed data

## Prerequisites

- Docker Desktop with `docker compose`
- Python 3.11+ if you want to run the backend outside Docker
- Flutter SDK and Android Studio if you want to run the frontend

## Repo Layout

- `frontend/flutter_app`: frontend app
- `backend`: backend service and local Python workflow
- `database`: Postgres Docker stack and SQL bootstrap
- `docker-compose.yml`: full local stack

## Environment Files

Use `backend/.env` as the shared local env file for Docker Compose.

If you need to recreate it:

```bash
cp backend/.env.example backend/.env
```

Important local defaults:

- backend HTTP port: `8000`
- Postgres host port: `5433`
- backend local DB URL: `postgresql+psycopg://postgres:postgres@localhost:5433/lockedin`

## Full Stack

Start backend and database together from the repo root:

```bash
docker compose --env-file backend/.env up -d --build
```

Stop the full stack:

```bash
docker compose --env-file backend/.env down
```

Endpoints:

- backend: `http://127.0.0.1:8000`
- health check: `http://127.0.0.1:8000/api/v1/health`
- Postgres: `localhost:5433`

## Database Only

Run only Postgres:

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
```

Stop it:

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env down
```

Reset it from scratch (destructive: ask for explicit approval immediately before running):

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env down -v
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
```

Notes:

- schema bootstrap lives in `database/initdb/10-schema.sql`
- seed data lives in `database/initdb/20-seed.sql`
- the backend assumes the database is already initialized

## Backend Only

If the database is already running separately, start just the backend:

```bash
docker compose -f backend/docker-compose.yml --env-file backend/.env up -d --build
```

Stop it:

```bash
docker compose -f backend/docker-compose.yml --env-file backend/.env down
```

This backend-only Docker stack connects to Postgres through `DOCKER_DATABASE_URL` in `backend/.env`.

## Backend Outside Docker

Run the database first, then start the backend locally:

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
cd backend
make install-venv
make init-env
make run
```

The local backend uses `DATABASE_URL` from `backend/.env` and, by default, expects Postgres on `localhost:5433`.

Useful backend commands:

```bash
cd backend
make test
make test-postgres
```

## Frontend

The frontend reads its backend URL at compile time through Flutter `--dart-define` values.

Create the local frontend env file:

```bash
cd frontend/flutter_app
cp .env.sample .env
```

Recommended values:

- Android emulator: `LOCKDIN_API_BASE_URL=http://10.0.2.2:8000`
- physical Android phone on the same Wi-Fi: use the Windows computer's Wi-Fi IPv4 address, for example `LOCKDIN_API_BASE_URL=http://192.168.2.44:8000`
- desktop/web on the same machine: `LOCKDIN_API_BASE_URL=http://127.0.0.1:8000`

Install dependencies and run:

```bash
cd frontend/flutter_app
flutter pub get
flutter run --dart-define-from-file=.env
```

The `-v` command deletes the named Postgres volume and all LockdIn database data stored in it.

### Physical Android phone from Windows

Run these commands in **PowerShell on the Windows development computer**, from the repository root.

1. Create the repeatable backend configuration if it does not exist:

   ```powershell
   Copy-Item backend/.env.example backend/.env
   ```

2. Start Postgres and the backend. This preserves the existing Docker database volume:

   ```powershell
   docker compose --env-file backend/.env up -d --build
   ```

3. Find the computer's Wi-Fi IPv4 address:

   ```powershell
   ipconfig
   ```

   Under the active **Wireless LAN adapter Wi-Fi**, copy the `IPv4 Address`, such as
   `192.168.2.44`. The address can change after reconnecting to Wi-Fi.

4. Copy the frontend environment file and set that address:

   ```powershell
   Copy-Item frontend/flutter_app/.env.sample frontend/flutter_app/.env
   ```

   Open `frontend/flutter_app/.env` in a text editor and set, for example:

   ```text
   LOCKDIN_API_BASE_URL=http://192.168.2.44:8000
   ```

5. With the phone connected by USB and USB debugging already authorized, confirm ADB sees it:

   ```powershell
   adb devices
   ```

6. Before running Flutter on Windows, enable **Developer Mode** in Windows Settings under
   **System > For developers**. Flutter plugins require permission to create symlinks. This is a
   Windows setting and must be enabled manually by the developer.

7. Run the debug app from the Flutter directory:

   ```powershell
   Set-Location frontend/flutter_app
   flutter pub get
   flutter run --dart-define-from-file=.env
   ```

Debug builds permit cleartext HTTP for local Wi-Fi development. Release builds do not include
that exception and should connect to an HTTPS backend.

Android keeps event-level usage history for only a few days. LockdIn therefore syncs at most the
last three days on the first run and advances an incremental watermark after every completely
successful sync. When the Accessibility service is enabled, its live upload queue is the only
usage source; the UsageStats fallback is paused to prevent double counting.

### Repair or clear development usage data

Rebuild derived app/category totals from accepted raw events without deleting raw data:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/api/v1/usage/aggregates/rebuild
```

Clearing usage rows or removing the Docker volume is destructive. Before doing either, inspect
the exact database/container and get explicit approval from the person whose development data is
stored there. A volume reset deletes **all** LockdIn Postgres data, not only usage counters. Do not
run `docker compose down -v` as routine troubleshooting.

Useful frontend commands:

```bash
cd frontend/flutter_app
flutter analyze
flutter test
```

## Suggested Team Workflows

### Fastest full local setup

```bash
docker compose --env-file backend/.env up -d --build
cd frontend/flutter_app
cp .env.sample .env
flutter pub get
flutter run --dart-define-from-file=.env
```

### Backend engineer workflow

```bash
docker compose -f database/docker-compose.yml --env-file backend/.env up -d
cd backend
make install-venv
make init-env
make run
```

### Frontend engineer workflow

```bash
docker compose --env-file backend/.env up -d --build
cd frontend/flutter_app
cp .env.sample .env
flutter pub get
flutter run --dart-define-from-file=.env
```

## Quick Verification

Check backend health:

```bash
curl http://127.0.0.1:8000/api/v1/health
```

If the stack is working, the backend should respond successfully and the frontend should be able to hit the same base URL configured in `frontend/flutter_app/.env`.
