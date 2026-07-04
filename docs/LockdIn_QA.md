# Quality Assurance Strategy

## Overview

This document outlines the quality assurance (QA) strategy for the **LockdIn** application—a screen time management app that helps users track and manage their device usage. This strategy ensures software reliability, maintainability, and a professional development workflow.

### Architecture

LockdIn is a full-stack application consisting of:

| Component | Technology | Status |
|-----------|------------|--------|
| **Frontend** | Flutter (Dart) | In Development |
| **Backend** | Python (FastAPI) | In Development |
| **Database** | SQLite (for now) | Active |

This QA strategy covers both frontend and backend components, with backend-specific sections to be expanded as that component is developed.

---

## A. Testing Goals

### Why Testing is Important

Testing is critical for the LockdIn project for the following reasons:

1. **User Trust**: Users rely on accurate screen time data to make informed decisions about their device usage
2. **Data Integrity**: Ensuring analytics and trends are calculated correctly is essential for the app's core functionality
3. **Cross-Platform Reliability**: The app runs on Android and potentially IOS in the future thus requiring consistent behavior across platforms
4. **State Management**: Using Riverpod for state management requires testing to ensure proper data flow
5. **Regression Failures**: To avoid new features breaking exisitng funtionality
6. **Backend Reliability**: The FastAPI backend must correctly enforce rules, store usage data, and serve accurate analytics to the Flutter frontend

### Risks the Team is Attempting to Reduce

| Risk Category | Layer | Description | Severity |
|--------------|-------|-------------|----------|
| Data Corruption | Backend | Incorrect tracking or storage of screen time data | High |
| UI Regressions | Frontend | Visual bugs or broken navigation between screens | Medium |
| State Management Bugs | Frontend | Improper state updates causing inconsistent UI | High |
| API Failures | Full Stack | Backend communication failures affecting data sync | High |
| Performance Issues | Full Stack | Slow rendering of charts, API latency | Medium |
| Accessibility Issues | Frontend | App not usable for users with disabilities | Medium |
| Authentication Failures | Backend | Users unable to login or unauthorized access | High |
| Database Inconsistency | Backend | Data integrity issues between tables/collections | High |
| Incorrect Rule Enforcement | Backend | Screen time rules not being applied or evaluated correctly | High |
| Incorrect Analytics Calculations | Backend | Aggregated usage data returned with wrong values | High |

### Critical Failures to Prevent

**Frontend (Flutter)**
1. **Navigation failures**: Users unable to access features (dashboard, analytics, settings)
2. **Chart rendering errors**: FL Chart components displaying incorrect or no data
3. **Onboarding failures**: New users unable to complete initial setup
4. **State management bugs**: UI not reflecting current data state

**Backend (FastAPI + PostgreSQL)**
1. **Screen time tracking inaccuracies**: Incorrect calculation or storage of usage statistics
2. **Data loss**: User preferences or accountability settings not being saved correctly
3. **Rules engine bugs**: Screen time rules not being evaluated or enforced correctly - e.g. boundary conditions where usage is exactly at the limit
4. **Authentication failures**: Security breaches or login issues
5. **API contract violations**: Routes returning wrong status codes or malformed response bodies
6. **Database constraint violations**: Duplicate records, orphaned rows, or failed upserts in aggregate tables

---

## B. Planned Types of Testing

Smoke tests cover the core, must-work paths, the minimum set of checks that confirm the app's critical functionality is intact (app launches, login works, screen time tracking records data, rules enforce correctly, main screens load without crashing). If a smoke test fails, the build is considered broken and shouldn't proceed further.
Regression tests cover everything else like edge cases, secondary features, less-common user flows, and previously-fixed bugs that confirm existing functionality still works correctly after changes, without blocking a build on their own.
Test cases will be manually segregated into smoke and regression.


### 1. Smoke Testing

#### Manual Verification Required

The following scenarios require manual verification:

- **Visual Design Verification**: Ensuring UI matches Figma prototypes
- **Cross-Device Testing**: Testing on various screen sizes and Android versions
- **Usability Testing**: Verifying intuitive user flows and interactions
- **Animation Quality**: Checking flutter_animate effects render smoothly
- **Backend Health Check**: Manually verifying '/health' endpoint responds correctly after deployment

#### How Manual Testing Will Be Performed

| Test Type | Procedure | Frequency |
|-----------|-----------|-----------|
| Visual Verification | Compare app screens against Figma designs | Each PR with UI changes |
| Device Testing | Run on physical Android devices | Weekly |
| User Flow Testing | Complete end-to-end user journeys manually | Before each release |

### 2. Unit Testing

#### Frontend Components to Be Unit Tested

| Component | Location | Testing Focus |
|-----------|----------|---------------|
| Riverpod Providers | `flutter_app/lib/features/*/` | State management logic |
| Data Models | `flutter_app/lib/shared/models/` | Serialization/deserialization |
| Theme Configuration | `flutter_app/lib/core/theme/` | Color and styling values |
| Utility Functions | `flutter_app/lib/shared/` | Helper function correctness |
| Analytics Calculations | `flutter_app/lib/features/analytics/` | Statistical computations |
| Rules Engine | `flutter_app/lib/features/rules/` | Rule evaluation logic |

#### Backend Components to Be Unit Tested (Planned)

Unit tests target the **services layer** — all business logic is tested in isolation by mocking the repository layer using Python's built-in `unittest.mock`. No database connection is required for these tests.

| Service | Location | Key Test Cases |
|---------|----------|----------------|
| `analytics_service` | `src/lockedin_backend/services/` | Aggregation math, empty data, single entry, category grouping |
| `enforcement_service` | `src/lockedin_backend/services/` | Rule triggered, rule not triggered, boundary (exactly at limit) |
| `rule_status_service` | `src/lockedin_backend/services/` | Active/inactive rules, overlapping rules, no rules configured |
| `usage_time` | `src/lockedin_backend/services/` | Timezone edge cases, midnight boundary, duration calculations |
| `accountability_service` | `src/lockedin_backend/services/` | Contact add/remove, notification trigger conditions |
| `app_identity` | `src/lockedin_backend/services/` | Identity resolution, unknown app handling |

Example pattern (mocking the repository):

```python
from unittest.mock import MagicMock
from lockedin_backend.services.analytics_service import AnalyticsService

def test_calculates_daily_total_correctly():
    mock_repo = MagicMock()
    mock_repo.get_usage_for_day.return_value = [
        MagicMock(duration_seconds=3600),
        MagicMock(duration_seconds=1800),
    ]
    service = AnalyticsService(repo=mock_repo)
    result = service.get_daily_total(profile_id=1, date=...)
    assert result == 5400

def test_returns_zero_for_empty_usage():
    mock_repo = MagicMock()
    mock_repo.get_usage_for_day.return_value = []
    service = AnalyticsService(repo=mock_repo)
    result = service.get_daily_total(profile_id=1, date=...)
    assert result == 0
```

#### Testing Frameworks

**Frontend (Flutter)**
- **Framework**: `flutter_test` (built-in Flutter testing)
- **State Testing**: `riverpod` testing utilities
- **Mocking**: `mockito` for dependency mocking

**Backend (Planned)**
- **Framework**: 'pytest'
- **Mocking**: 'unittest.mock' (Python stdlib - no extra dependencies)
- **Database Testing**: Real PostgreSQL instance via Docker (same 'database/docker-compose.yml' already in the repo)

#### Minimum Coverage Goals

| Component Type | Target Coverage |
|---------------|-----------------|
| Frontend Business Logic | 80% |
| Frontend Data Models | 90% |
| Frontend Utility Functions | 85% |
| Backend Services (unit) | 90% |
| Backend Repositories (integration) | 80% |
| Backend API Routes | 85% |
| Backend Models / Schemas | 95% |
| **Overall Project** | **85%** |

---

### 3. Integration Testing

#### Frontend Integration Points

| Integration Point | Components Involved | Test Focus |
|-------------------|---------------------|------------|
| Navigation Flow | GoRouter + Feature Screens | Proper routing between features |
| State Persistence | Riverpod + SharedPreferences | Data persists across app restarts |
| Chart Data Flow | FL Chart + Analytics Provider | Charts display correct data |
| Theme Application | AppTheme + All Widgets | Consistent styling throughout |

#### Backend Integration Testing — Repositories + PostgreSQL

Integration tests verify that repository classes correctly interact with a **real PostgreSQL database**. Each test runs inside a transaction that is rolled back after the test completes, ensuring full isolation without truncating tables.

`conftest.py` setup:

```python
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from lockedin_backend.db.base import Base

TEST_DB_URL = "postgresql://lockedin:secret@localhost:5433/lockedin_test"

@pytest.fixture(scope="session")
def db_engine():
    engine = create_engine(TEST_DB_URL)
    Base.metadata.create_all(engine)
    yield engine
    Base.metadata.drop_all(engine)

@pytest.fixture(scope="function")
def db_session(db_engine):
    connection = db_engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection)
    yield session
    session.close()
    transaction.rollback()  # each test gets a clean slate
    connection.close()
```

| Repository | Key Test Cases |
|------------|----------------|
| `rule_repository` | Create, read, update, delete; fetch by profile; no rules edge case |
| `usage_repository` | Insert event, fetch by date range, empty range, overlapping timestamps |
| `enforcement_event_repository` | Create event, fetch by rule ID, fetch by time window |
| `accountability_repository` | Add contact, remove contact, duplicate contact handling |
| `usage_daily_app_aggregate_repository` | Upsert behavior, correct aggregate values, missing day |
| `usage_daily_category_aggregate_repository` | Upsert behavior, correct category totals |
| `preferences_repository` | Save preferences, overwrite preferences, default values |

#### Full-Stack Integration

| Integration Point | Components Involved | Test Focus |
|-------------------|---------------------|------------|
| API Routes + Services + DB | FastAPI TestClient + PostgreSQL | Full request/response with real data |
| Frontend + Backend | Flutter HTTP client + FastAPI | Correct request format, response deserialization |

---

### 4. End-to-End (E2E) Testing

#### User Workflows to Test

| Workflow | Steps | Priority |
|----------|-------|----------|
| **Onboarding Flow** | Launch app → Complete onboarding → Reach dashboard | High |
| **View Analytics** | Dashboard → Analytics → View trends chart | High |
| **Configure Rules** | Dashboard → Rules → Add new rule → Save | High |
| **Rule Enforcement** | Usage posted → Rule limit reached → Enforcement event created | High |
| **Accountability Setup** | Settings → Accountability → Add partner → Confirm | Medium |
| **Trend Analysis** | Dashboard → Trends → Select date range → View data | Medium |

#### E2E Testing Implementation

The backend API route tests (using FastAPI's `TestClient`) serve as lightweight E2E tests for the backend, covering the full request → service → repository → PostgreSQL → response path in a single process. Full cross-stack Flutter + backend E2E testing is planned for a future sprint.

---

### 5. Performance / Load Testing

#### Frontend Performance Testing

| Test Scenario | Tool | Success Criteria |
|---------------|------|------------------|
| Chart Rendering | Flutter DevTools | Charts render in < 100ms |
| App Startup | Flutter DevTools | Cold start < 3 seconds |
| Memory Usage | Flutter DevTools | < 150MB memory footprint |
| Animation FPS | Flutter DevTools | Maintain 60 FPS during animations |

#### Backend Performance Testing (Planned)

| Test Scenario | Tool | Success Criteria |
|---------------|------|------------------|
| API Response Time | k6 / Artillery | < 200ms average response |
| Concurrent Users | k6 / Artillery | Support 100+ concurrent users |
| Database Queries | PostgreSQL 'EXPLAIN ANALYZE' | < 50ms per query |
| Aggregate Upserts Under Load | k6 | No deadlocks or constraint violations |

#### Performance Testing Implementation

TBD

#### Potential Bottlenecks

**Frontend**
1. **FL Chart Rendering**: Complex charts with large datasets may cause jank
2. **Riverpod State Updates**: Excessive rebuilds can impact performance
3. **SharedPreferences I/O**: Frequent reads/writes may slow the app
4. **Image Assets**: Large images can increase memory usage

**Backend (Planned)**
1. **Database Queries**: Unoptimized queries under high load
2. **API Rate Limiting**: Handling burst traffic against enforcement evaluation logic
3. **Authentication Overhead**: Token validation latency
4. **Concurrent upserts**: Concurrent upserts to 'usage_daily_app_aggregate' and 'usage_daily_category_aggregate'

### 6. Security Testing

#### Security Concerns Relevant to the Project

| Concern | Layer | Risk Level | Mitigation |
|---------|-------|------------|------------|
| **Insecure Data Storage** | Frontend | High | Use encrypted SharedPreferences for sensitive data |
| **API Key Exposure** | Full Stack | High | Store keys in environment variables, never in code |
| **User Data Privacy** | Full Stack | High | Minimize data collection, follow privacy best practices |
| **Input Validation** | Full Stack | Medium | Sanitize all user inputs on client and server |
| **SQL Injection** | Backend | High | Use SQLAlchemy ORM with parameterized queries — never raw string interpolation |
| **Dependency Vulnerabilities** | Full Stack | Medium | Regular dependency audits (`pip audit`, `flutter pub outdated`) |
| **CORS Misconfiguration** | Backend | Medium | Strict CORS policy configured in FastAPI |
| **Rate Limiting** | Backend | Medium | Implement request throttling on high-frequency endpoints |
| **Unvalidated API Input** | Backend | High | Pydantic schemas enforce type and constraint validation on all request bodies |

#### Security Testing Procedures

**Frontend**
1. **Static Analysis**: Use `flutter analyze` to detect security issues
2. **Dependency Audit**: Run `flutter pub outdated` to check for vulnerable packages
3. **Code Review**: Security-focused review of data handling
4. **Input Fuzzing**: Test edge cases in user input fields

**Backend (Planned)**
1. **OWASP Top 10 Review**: OWASP pass before each release
2. **Dependency Scanning**: Use tools like Snyk or Dependabot
3. **Penetration Testing**: Test authentication and authorization
4. **API Security Audit**: Validate input sanitization, rate limiting

---

## C. Pull Request Quality Rules

### Required PR Checklist

All Pull Requests must meet the following criteria before merging:

#### Automated Checks (Required to Pass)

- [ ] All CI pipeline checks pass (GitHub Actions)
- [ ] No merge conflicts with target branch

**Frontend PRs:**
- [ ] `flutter analyze` returns no errors
- [ ] `flutter test` passes all unit tests

**Backend PRs (when applicable):**
- [ ] 'pytest' passes all unit, integration, and API tests
- [ ] 'pylint' or 'ruff' linting returns no errors
- [ ] 'pip audit' returns no high-severity vulnerabilities

#### Code Review Requirements

- [ ] At least **one team member** must approve the PR
- [ ] All review comments must be addressed or resolved
- [ ] Changes are within scope of the associated issue/task

#### Branch Protection Rules

> **Note**: GitHub branch protection rules cannot be enforced on this private repository due to GitHub Free tier limitations (requires GitHub Team or Enterprise). The team will rely on GitHub Actions CI workflows and team agreement to enforce quality standards.

| Rule | Intended Enforcement | Actual Enforcement |
|------|---------------------|-------------------|
| Direct pushes to `main` | Blocked | ⚠️ Team agreement (CI still runs) |
| PR required for merge | Required | ⚠️ Team agreement |
| Status checks must pass | Required | ✅ **CI workflow runs on all PRs** |
| Reviewer approval required | Required (1 minimum) | ⚠️ Team agreement |

**What IS enforced automatically:**
- GitHub Actions CI runs on every PR to `main`
- Linting (`flutter analyze`) and tests (`flutter test`) execute automatically
- Build verification (Android APK, Windows app) runs on passing PRs
- PR shows ✅/❌ status based on CI results

**Team Agreement (Honor System):**
- Do not merge PRs with failing CI checks
- Request at least one teammate review before merging
- Do not push directly to `main` always use feature branches and PRs

#### PR Guidelines

1. **Descriptive Title**: Use format `[Feature/hotfix/bug: Brief description`
2. **Issue Reference**: Link related GitHub Issues in PR description
3. **Testing Evidence**: Include screenshots or test results for UI changes
4. **Small, Focused Changes**: PRs should address a single concern
5. **Documentation**: Update relevant docs if behavior changes

### Merge Strategy

- **Merge Method**: Squash and merge (keeps main branch history clean)
- **Branch Deletion**: Delete feature branches after merge
- **Conflict Resolution**: Resolve conflicts locally before requesting review

---

## D. CI/CD Setup Using GitHub Actions

### Workflow Files

Two separate CI workflows are configured — one for the Flutter frontend and one for the Python backend. Both trigger on every pull request and push.

#### Backend CI — `.github/workflows/backend-ci.yml`

```yaml
name: Backend CI

on:
  pull_request:
    paths:
      - 'backend/**'
  push:
    paths:
      - 'backend/**'

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: lockedin_test
          POSTGRES_USER: lockedin
          POSTGRES_PASSWORD: secret
        ports:
          - 5433:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v3

      - name: Install dependencies
        run: uv sync
        working-directory: backend

      - name: Run linter (ruff)
        run: uv run ruff check src/
        working-directory: backend

      - name: Run tests with coverage
        run: uv run pytest tests/ -v --cov=src --cov-report=term-missing
        working-directory: backend
        env:
          DATABASE_URL: postgresql://lockedin:secret@localhost:5433/lockedin_test

      - name: Security audit
        run: uv run pip-audit
        working-directory: backend
```

#### Frontend CI — `.github/workflows/frontend-ci.yml`

```yaml
name: Frontend CI

on:
  pull_request:
    paths:
      - 'frontend/**'
  push:
    paths:
      - 'frontend/**'

jobs:
  # ============================================
  # FRONTEND (Flutter) - Code Quality
  # ============================================
  
  frontend-analyze:
    name: Frontend - Analyze Code
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true
      
      - name: Install dependencies
        working-directory: ./flutter_app
        run: flutter pub get
      
      - name: Run Flutter Analyzer (Linting)
        working-directory: ./flutter_app
        run: flutter analyze --fatal-infos
      
      - name: Check Dart formatting
        working-directory: ./flutter_app
        run: dart format --set-exit-if-changed .

  frontend-test:
    name: Frontend - Run Tests
    runs-on: ubuntu-latest
    needs: frontend-analyze
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true
      
      - name: Install dependencies
        working-directory: ./flutter_app
        run: flutter pub get
      
      - name: Run tests with coverage
        working-directory: ./flutter_app
        run: flutter test --coverage
      
      - name: Upload coverage reports
        uses: codecov/codecov-action@v4
        with:
          file: ./flutter_app/coverage/lcov.info
          fail_ci_if_error: false
        continue-on-error: true

  # ============================================
  # FRONTEND (Flutter) - Build Artifacts
  # ============================================
  
  frontend-build-android:
    name: Frontend - Build Android APK
    runs-on: ubuntu-latest
    needs: frontend-test
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true
      
      - name: Install dependencies
        working-directory: ./flutter_app
        run: flutter pub get
      
      - name: Build Android APK (Debug)
        working-directory: ./flutter_app
        run: flutter build apk --debug
      
      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: flutter_app/build/app/outputs/flutter-apk/app-debug.apk
          retention-days: 7

  frontend-build-windows:
    name: Frontend - Build Windows App
    runs-on: windows-latest
    needs: frontend-test
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true
      
      - name: Install dependencies
        working-directory: ./flutter_app
        run: flutter pub get
      
      - name: Build Windows App
        working-directory: ./flutter_app
        run: flutter build windows --debug
      
      - name: Upload Windows artifact
        uses: actions/upload-artifact@v4
        with:
          name: windows-app
          path: flutter_app/build/windows/x64/runner/Debug/
          retention-days: 7
```

---

## E. Testing Responsibilities

### Team Member Roles

| Role | Responsibilities |
|------|------------------|
| **Developer** | Write unit tests for new code, fix failing tests |
| **Code Reviewer** | Verify test coverage in PRs, suggest additional tests |
| **QA Lead** | Maintain QA documentation, coordinate E2E testing |
| **All Members** | Participate in manual testing before releases |

### Testing Schedule

| Activity | Frequency |
|----------|-----------|
| Unit Tests (smoke only)| Every PR (automated) |
| Integration Tests (smoke only)| Every PR (automated) |
| Manual Smoke Testing + Full Regression Suite | Weekly |
| E2E Testing | Before major releases |
| Performance Testing | Monthly |
| Security Audit | Monthly |

---

## F. Test File Organization

### Frontend (Flutter)
```
flutter_app/
├── test/
│   ├── unit/
│   │   ├── models/
│   │   ├── providers/
│   │   └── utils/
│   ├── widget/
│   │   ├── features/
│   │   └── shared/
│   └── integration/
│       └── flows/
├── integration_test/
│   └── app_test.dart
```

### Backend (Planned: To be done)
```
backend/tests/
├── unit/
│   ├── test_analytics_service.py
│   ├── test_enforcement_service.py
│   ├── test_rule_status_service.py
│   ├── test_usage_time.py
│   └── test_app_identity.py
├── integration/
│   ├── test_rule_repository.py
│   ├── test_usage_repository.py
│   ├── test_enforcement_event_repository.py
│   ├── test_accountability_repository.py
│   ├── test_preferences_repository.py
│   └── test_usage_aggregate_repositories.py
├── api/
│   ├── test_rules_routes.py
│   ├── test_analytics_routes.py
│   ├── test_enforcement_routes.py
│   ├── test_usage_routes.py
│   ├── test_accountability_routes.py
│   └── test_health_routes.py
├── conftest.py
└── __init__.py
```

## G. Continuous Improvement

The QA strategy will be reviewed and updated:

- After each sprint retrospective
- When new features are added
- When new testing tools become available
- Based on production issues and user feedback

---

*Document Version: 1.0*  
*Last Updated: June 2026*  
*Maintained by: LockdIn Development Team*
