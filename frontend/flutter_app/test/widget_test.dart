// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lockdin_app/features/preferences/data/preferences_models.dart';
import 'package:lockdin_app/features/preferences/data/preferences_provider.dart';
import 'package:lockdin_app/main.dart';
import 'package:lockdin_app/shared/models/models.dart';

class _TestPreferencesController extends PreferencesController {
  @override
  Future<AppPreferences> build() async {
    return const AppPreferences(
      hasCompletedOnboarding: false,
      defaultDailyLimitMinutes: 180,
      notificationTone: NotificationTone.professional,
      textSizePercent: 100,
      highContrast: false,
      largeTapTargets: false,
    );
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 2560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesControllerProvider.overrideWith(_TestPreferencesController.new),
        ],
        child: LockdInApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
  });
}
