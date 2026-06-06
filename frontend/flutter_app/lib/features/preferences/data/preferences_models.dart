import '../../../../shared/models/models.dart';

class AppPreferences {
  const AppPreferences({
    required this.hasCompletedOnboarding,
    required this.defaultDailyLimitMinutes,
    required this.notificationTone,
    required this.textSizePercent,
    required this.highContrast,
    required this.largeTapTargets,
  });

  final bool hasCompletedOnboarding;
  final int defaultDailyLimitMinutes;
  final NotificationTone notificationTone;
  final int textSizePercent;
  final bool highContrast;
  final bool largeTapTargets;

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    final accessibility = json['accessibility'] as Map<String, dynamic>;

    return AppPreferences(
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool,
      defaultDailyLimitMinutes: json['defaultDailyLimitMinutes'] as int,
      notificationTone: _notificationToneFromJson(
        json['notificationTone'] as String,
      ),
      textSizePercent: accessibility['textSizePercent'] as int,
      highContrast: accessibility['highContrast'] as bool,
      largeTapTargets: accessibility['largeTapTargets'] as bool,
    );
  }
}

NotificationTone _notificationToneFromJson(String value) {
  return switch (value) {
    'fun' => NotificationTone.fun,
    'edgy' => NotificationTone.edgy,
    _ => NotificationTone.professional,
  };
}
