# LockdIn Flutter App

A screen time management app built with Flutter, converted from the Figma prototype.

## Prerequisites

- [Flutter SDK Manual Install](https://docs.flutter.dev/install/manual)
- [Android Studio](https://developer.android.com/studio) with Flutter plugin
- A virtual device in Android Studio
- Android SDK (usually comes with Android Studio)
- Git

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/SED800/LockedIn.git
cd LockedIn/flutter_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

You can use the Android Studio App to run the code on an Android Emulator or as a Windows app.

If you just want to run Windows app version, jump to section 3.2 (easier).

**3.1 Android Studio Setup**

1. Open Android Studio
2. File -> Open -> Select `flutter_app` folder
3. Wait for Gradle sync to complete
4. If prompted, click "Get dependencies" or run `flutter pub get` in terminal
5. **If using an emulator**, go to Tools -> Device Manager -> Create/start an emulator
6. Select device from "Select Device" dropdown (Emulator device or Windows) → Click Run

**3.2 On Windows (requires Developer Mode and is faster to build and run):**
```bash
flutter run -d windows
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── router/               # GoRouter navigation
│   │   └── app_router.dart
│   └── theme/                # Design system
│       ├── app_colors.dart   # Color tokens
│       ├── app_text_styles.dart
│       ├── app_theme.dart    # ThemeData
│       ├── spacing.dart      # Spacing constants
│       └── theme.dart        # Barrel export
├── shared/
│   ├── models/               # Data models
│   │   └── models.dart
│   └── widgets/              # Reusable components
│       ├── buttons.dart
│       ├── cards.dart
│       ├── app_header.dart
│       ├── icon_box.dart
│       ├── progress_indicators.dart
│       ├── form_widgets.dart
│       └── widgets.dart      # Barrel export
└── features/
    ├── onboarding/           # Welcome, permissions, default rule
    ├── dashboard/            # Main dashboard screen
    ├── rules/                # Lockdown rules management
    ├── trends/               # Usage trends & charts
    ├── settings/             # Notifications, accessibility, privacy
    ├── accountability/       # Partner setup
    └── analytics/            # Weekly summary
```

## Tech Stack

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `dio` | HTTP client |
| `flutter_hooks` | React-style hooks |
| `fl_chart` | Charts & graphs |
| `flutter_animate` | Animations |
| `shared_preferences` | Local storage |

## Available Screens

| Screen | Route | Description |
|--------|-------|-------------|
| Onboarding Welcome | `/` | Initial welcome screen |
| Onboarding Permissions | `/onboarding/permissions` | Permission requests |
| Onboarding Default Rule | `/onboarding/default-rule` | Set daily limit |
| Dashboard | `/dashboard` | Main app screen |
| Lockdown Rules | `/rules` | Manage app rules |
| Trends | `/trends` | Usage statistics |
| Notification Settings | `/settings/notifications` | Notification preferences |
| Accessibility Settings | `/settings/accessibility` | A11y options |
| Privacy Policy | `/settings/privacy` | Privacy info |
| Accountability | `/accountability` | Partner management |
| Analytics Summary | `/analytics` | Weekly review |

## Development

### Fix Lint Issues
```bash
dart fix --apply
```

### Analyze Code
```bash
flutter analyze
```

### Run Tests
```bash
flutter test
```

### Build APK
```bash
flutter build apk --debug
```

### Build Release APK
```bash
flutter build apk --release
```

## Troubleshooting

### "No pubspec.yaml file found"
Make sure you're in the `flutter_app` directory:
```bash
cd flutter_app
```

### "Developer Mode required" (Windows)
1. Settings -> Privacy & security -> For developers
2. Enable Developer Mode
3. Retry `flutter run -d windows`

### Gradle build fails
```bash
flutter clean
flutter pub get
flutter run
```

### Emulator not showing
1. Android Studio -> Tools -> Device Manager
2. Create a new device (e.g., Pixel 6, API 34)
3. Start the emulator
4. Run the app

## Design Tokens

Colors, typography, and spacing are extracted from the original Figma design:

- **Primary:** `#7A5AF8` (Purple)
- **Background:** `#1C1C1C` (Dark)
- **Card Background:** `#262626`
- **Success:** `#22C55E`
- **Error:** `#EF4444`

See `lib/core/theme/` for complete design system.

## Contributing

1. Create a feature branch
2. Make changes
3. Run `flutter analyze` to check for issues
4. Submit a pull request
