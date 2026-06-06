import 'package:flutter_riverpod/flutter_riverpod.dart';

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
