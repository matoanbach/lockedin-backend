# LockdIn Flutter Client

This directory contains the Flutter user interface and native Android usage/enforcement
integration for LockdIn.

## Requirements

- Flutter stable with Dart compatible with `^3.12.0`
- Android Studio and Android SDK/platform tools
- JDK 17 or newer
- Windows Developer Mode for plugin symlinks when building on Windows
- a running LockdIn backend

The Android application requires API 24 or newer because the resolved AppAuth 12.0.2 Android
library declares that minimum.

## Authentication Status

The client fetches `/api/v1/auth/config`, opens the system browser through AppAuth for Authorization
Code + PKCE S256, stores rotating tokens in platform-backed secure storage, validates the backend
session, and guards onboarding/product routes. Access tokens are injected only into protected
requests; renewal is single-flight and a 401 is retried at most once. Native upload credentials stay
in process memory. Pre-login rows remain unclaimed until Import or Discard, and other-account rows
remain quarantined.

These paths have analyzer, 52-test Flutter, Android JVM, and debug-build evidence. On August 8,
2026, a Samsung SM-A528B also physically verified CA-trusted bootstrap, AppAuth registration and
normal sign-in pages, redirect back to LockdIn, token exchange, protected-session bootstrap,
authenticated onboarding, and sign-out that remained cleared after an app-process restart. A
successful refresh after a long-offline provider session, real SQLite v1-to-v2 migration,
backup/restore behavior, and production release behavior have not been verified.

## Configure the Backend URL

From this directory:

```powershell
Copy-Item .env.sample .env
```

Set one compile-time address:

```text
# Android emulator
LOCKDIN_API_BASE_URL=http://10.0.2.2:8000

# Windows client on the backend host
LOCKDIN_API_BASE_URL=http://127.0.0.1:8000

# Physical Android phone; replace with the host's current Wi-Fi IPv4 address
LOCKDIN_API_BASE_URL=http://192.168.2.44:8000
```

Debug Android builds allow cleartext HTTP for trusted local testing. Release builds should use an
HTTPS backend.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

Select a device explicitly when needed:

```bash
flutter devices
flutter run -d windows --dart-define-from-file=.env
flutter run -d <android-device-id> --dart-define-from-file=.env
```

## Test and Build

```bash
flutter analyze
flutter test --coverage
dart format --set-exit-if-changed .
flutter build apk --debug --dart-define-from-file=.env
flutter build windows --debug --dart-define-from-file=.env
```

Native Android tests:

```powershell
Set-Location android
.\gradlew.bat testDebugUnitTest
```

The current Android release build uses debug signing and is not ready for app-store distribution.

## Main Routes

| Screen | Route |
| --- | --- |
| Bootstrap | `/` |
| Sign in / reauthenticate | `/auth/login` |
| Unclaimed data choice | `/auth/data-choice` |
| Welcome | `/onboarding` |
| Permission guidance | `/onboarding/permissions` |
| Default limit | `/onboarding/default-rule` |
| Dashboard | `/dashboard` |
| Rules | `/rules` |
| Trends | `/trends` |
| Weekly Summary | `/analytics` |
| Device Permissions | `/settings/device-permissions` |
| Notifications | `/settings/notifications` |
| Display Accessibility | `/settings/display-accessibility` |
| Privacy | `/settings/privacy` |
| Accountability | `/accountability` |

## Structure

```text
lib/
├── core/       API, notifications, router, and theme
├── features/   onboarding, dashboard, rules, trends, settings, usage, and enforcement
├── shared/     shared models and widgets
└── main.dart   application entry point and lifecycle listeners

android/app/src/main/kotlin/com/lockdin/lockdin_app/
├── MainActivity.kt
├── LockdinAccessibilityService.kt
├── NativeUsageUploader.kt
├── RuleEnforcementStore.kt
├── UsageEventReconstructor.kt
└── UsageUploadQueueStore.kt
```

## Permission Model

- Usage Access enables UsageStats fallback synchronization.
- Notifications enable visible warnings.
- Accessibility enables live foreground tracking and soft intervention.

The device owner controls these settings. Do not change them silently or clear app data as routine
troubleshooting.

## Troubleshooting

- **Backend unavailable:** verify the backend health URL, current host IP, firewall, Wi-Fi, and
  compiled `.env`.
- **No Android usage:** confirm Usage Access and wait for Android to finalize recent activity.
- **Manual sync creates zero rows:** automatic sync may already have imported the sessions.
- **Gradle migration warnings:** currently known and non-blocking; track before AGP/Gradle upgrades.
- **Windows symlink error:** enable Windows Developer Mode and rerun `flutter pub get`.

For end-user behavior, see the [User Guide](../../docs/USER_GUIDE.md). For architecture and testing
answers, see the [Thesis Defense Guide](../../docs/THESIS_DEFENSE_GUIDE.md) and
[Testing Evidence](../../docs/TESTING.md).
