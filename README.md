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

Reset it from scratch:

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
- desktop/web on the same machine: `LOCKDIN_API_BASE_URL=http://127.0.0.1:8000`

Install dependencies and run:

```bash
cd frontend/flutter_app
flutter pub get
flutter run --dart-define-from-file=.env
```

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
