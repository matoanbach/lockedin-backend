import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track onboarding completion status.
final hasCompletedOnboardingProvider =
    NotifierProvider<HasCompletedOnboardingNotifier, bool>(
  HasCompletedOnboardingNotifier.new,
);

class HasCompletedOnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void set(bool value) => state = value;
  void complete() => state = true;
}

/// Provider for granted permissions during onboarding.
final onboardingPermissionsProvider =
    NotifierProvider<OnboardingPermissionsNotifier, OnboardingPermissions>(
  OnboardingPermissionsNotifier.new,
);

class OnboardingPermissions {
  final bool usageAccess;
  final bool notifications;
  final bool accessibility;

  const OnboardingPermissions({
    this.usageAccess = false,
    this.notifications = false,
    this.accessibility = false,
  });

  bool get allGranted => usageAccess && notifications && accessibility;

  OnboardingPermissions copyWith({
    bool? usageAccess,
    bool? notifications,
    bool? accessibility,
  }) {
    return OnboardingPermissions(
      usageAccess: usageAccess ?? this.usageAccess,
      notifications: notifications ?? this.notifications,
      accessibility: accessibility ?? this.accessibility,
    );
  }
}

class OnboardingPermissionsNotifier extends Notifier<OnboardingPermissions> {
  @override
  OnboardingPermissions build() => const OnboardingPermissions();

  void toggleUsageAccess() {
    state = state.copyWith(usageAccess: !state.usageAccess);
  }

  void toggleNotifications() {
    state = state.copyWith(notifications: !state.notifications);
  }

  void toggleAccessibility() {
    state = state.copyWith(accessibility: !state.accessibility);
  }

  void reset() {
    state = const OnboardingPermissions();
  }
}

/// Provider for the default daily limit set during onboarding.
final defaultDailyLimitProvider =
    NotifierProvider<DefaultDailyLimitNotifier, int>(
  DefaultDailyLimitNotifier.new,
);

class DefaultDailyLimitNotifier extends Notifier<int> {
  @override
  int build() => 180; // 3 hours in minutes
  
  void set(int value) => state = value;
}
