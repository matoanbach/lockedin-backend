import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lockdin_app/features/onboarding/presentation/screens/app_bootstrap_screen.dart';
import 'package:lockdin_app/features/onboarding/presentation/screens/onboarding_welcome_screen.dart';
import 'package:lockdin_app/features/onboarding/presentation/screens/onboarding_permissions_screen.dart';
import 'package:lockdin_app/features/onboarding/presentation/screens/onboarding_default_rule_screen.dart';
import 'package:lockdin_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:lockdin_app/features/rules/presentation/screens/lockdown_rules_screen.dart';
import 'package:lockdin_app/features/trends/presentation/screens/trends_screen.dart';
import 'package:lockdin_app/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:lockdin_app/features/accountability/presentation/screens/accountability_screen.dart';
import 'package:lockdin_app/features/settings/presentation/screens/accessibility_settings_screen.dart';
import 'package:lockdin_app/features/analytics/presentation/screens/analytics_summary_screen.dart';
import 'package:lockdin_app/features/settings/presentation/screens/privacy_policy_screen.dart';

/// Route names for type-safe navigation.
abstract class AppRoutes {
  static const String bootstrap = '/';

  // Onboarding
  static const String onboardingWelcome = '/onboarding';
  static const String onboardingPermissions = '/onboarding/permissions';
  static const String onboardingDefaultRule = '/onboarding/default-rule';

  // Main
  static const String dashboard = '/dashboard';
  static const String lockdownRules = '/rules';
  static const String trends = '/trends';
  static const String analytics = '/analytics';

  // Settings
  static const String notificationSettings = '/settings/notifications';
  static const String accessibilitySettings = '/settings/accessibility';
  static const String privacyPolicy = '/settings/privacy';

  // Accountability
  static const String accountability = '/accountability';
}

/// Main router provider using GoRouter.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.bootstrap,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.bootstrap,
        name: 'bootstrap',
        pageBuilder: (context, state) => const MaterialPage(
          child: AppBootstrapScreen(),
        ),
      ),

      // === Onboarding Routes ===
      GoRoute(
        path: AppRoutes.onboardingWelcome,
        name: 'onboarding-welcome',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingWelcomeScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingPermissions,
        name: 'onboarding-permissions',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingPermissionsScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingDefaultRule,
        name: 'onboarding-default-rule',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingDefaultRuleScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),

      // === Main Routes ===
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const DashboardScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.lockdownRules,
        name: 'lockdown-rules',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LockdownRulesScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.trends,
        name: 'trends',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const TrendsScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.analytics,
        name: 'analytics',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AnalyticsSummaryScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),

      // === Settings Routes ===
      GoRoute(
        path: AppRoutes.notificationSettings,
        name: 'notification-settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationSettingsScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.accessibilitySettings,
        name: 'accessibility-settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AccessibilitySettingsScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        name: 'privacy-policy',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PrivacyPolicyScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),

      // === Accountability ===
      GoRoute(
        path: AppRoutes.accountability,
        name: 'accountability',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AccountabilityScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        body: Center(
          child: Text('Page not found: ${state.uri}'),
        ),
      ),
    ),
  );
});

/// Slide transition from right.
Widget _slideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    )),
    child: child,
  );
}

/// Fade transition.
Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: animation,
    child: child,
  );
}
