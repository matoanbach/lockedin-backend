import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/enforcement/data/live_intervention_provider.dart';
import 'package:lockdin_app/features/preferences/data/preferences_models.dart';
import 'package:lockdin_app/features/preferences/data/preferences_provider.dart';
import 'package:lockdin_app/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:lockdin_app/shared/models/models.dart';

class _TestPreferencesController extends PreferencesController {
  NotificationTone? updatedTone;

  @override
  Future<AppPreferences> build() async =>
      _preferences(NotificationTone.professional);

  @override
  Future<AppPreferences> updatePreferences({
    bool? hasCompletedOnboarding,
    int? defaultDailyLimitMinutes,
    NotificationTone? notificationTone,
    int? textSizePercent,
    bool? highContrast,
    bool? largeTapTargets,
  }) async {
    updatedTone = notificationTone;
    final updated = _preferences(
      notificationTone ?? NotificationTone.professional,
    );
    state = AsyncData(updated);
    return updated;
  }
}

class _RecordingLiveEnforcementRepository extends LiveEnforcementRepository {
  final cachedTones = <String>[];

  @override
  Future<void> cacheNotificationTone(String tone) async {
    cachedTones.add(tone);
  }
}

void main() {
  testWidgets('saving a tone immediately refreshes the native cache', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferencesController = _TestPreferencesController();
    final nativeRepository = _RecordingLiveEnforcementRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesControllerProvider.overrideWith(
            () => preferencesController,
          ),
          liveEnforcementRepositoryProvider.overrideWithValue(nativeRepository),
        ],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fun'));
    await tester.pump();
    final saveChanges = find.text('Save Changes');
    await tester.ensureVisible(saveChanges);
    await tester.tap(saveChanges);
    await tester.pumpAndSettle();

    expect(preferencesController.updatedTone, NotificationTone.fun);
    expect(nativeRepository.cachedTones, ['fun']);
    expect(find.text('Notification tone updated to Fun'), findsOneWidget);
  });
}

AppPreferences _preferences(NotificationTone tone) {
  return AppPreferences(
    hasCompletedOnboarding: true,
    defaultDailyLimitMinutes: 180,
    notificationTone: tone,
    textSizePercent: 100,
    highContrast: false,
    largeTapTargets: false,
  );
}
