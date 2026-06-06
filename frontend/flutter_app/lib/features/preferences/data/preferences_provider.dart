import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/models/models.dart';
import 'preferences_models.dart';
import 'preferences_repository.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository(ref.watch(dioProvider));
});

final preferencesControllerProvider = AsyncNotifierProvider<
    PreferencesController, AppPreferences>(PreferencesController.new);

class PreferencesController extends AsyncNotifier<AppPreferences> {
  PreferencesRepository get _repository => ref.read(preferencesRepositoryProvider);

  @override
  Future<AppPreferences> build() {
    return _repository.fetchPreferences();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.fetchPreferences);
  }

  Future<AppPreferences> updatePreferences({
    bool? hasCompletedOnboarding,
    int? defaultDailyLimitMinutes,
    NotificationTone? notificationTone,
    int? textSizePercent,
    bool? highContrast,
    bool? largeTapTargets,
  }) async {
    final updated = await _repository.updatePreferences({
      'hasCompletedOnboarding':? hasCompletedOnboarding,
      'defaultDailyLimitMinutes':? defaultDailyLimitMinutes,
      'notificationTone':? notificationTone?.name,
      'textSizePercent':? textSizePercent,
      'highContrast':? highContrast,
      'largeTapTargets':? largeTapTargets,
    });

    state = AsyncData(updated);
    return updated;
  }
}
