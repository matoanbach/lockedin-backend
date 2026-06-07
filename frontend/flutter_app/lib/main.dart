import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/analytics/data/analytics_provider.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'shared/models/models.dart';
import 'features/enforcement/data/live_intervention_provider.dart';
import 'features/enforcement/data/rule_alert_provider.dart';
import 'features/preferences/data/preferences_provider.dart';
import 'features/rules/data/rules_provider.dart';
import 'features/usage/data/usage_sync_provider.dart';

void main() {
  runApp(const ProviderScope(child: LockdInApp()));
}

class LockdInApp extends ConsumerStatefulWidget {
  const LockdInApp({super.key});

  @override
  ConsumerState<LockdInApp> createState() => _LockdInAppState();
}

class _LockdInAppState extends ConsumerState<LockdInApp>
    with WidgetsBindingObserver {
  bool _didHandleInitialForeground = false;
  bool _isPresentingRuleAlert = false;
  bool _isPresentingLiveIntervention = false;
  bool _resumeRefreshInFlight = false;
  DateTime? _lastResumeRefreshStartedAt;
  ProviderSubscription<RuleAlert?>? _ruleAlertSubscription;
  ProviderSubscription<PendingIntervention?>? _liveInterventionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ruleAlertSubscription = ref.listenManual<RuleAlert?>(ruleAlertProvider, (
      previous,
      next,
    ) {
      if (next == null || _isPresentingRuleAlert) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_presentRuleAlert(next));
      });
    });
    _liveInterventionSubscription = ref.listenManual<PendingIntervention?>(
      liveInterventionProvider,
      (previous, next) {
        if (next == null || _isPresentingLiveIntervention) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_presentLiveIntervention(next));
        });
      },
    );
    unawaited(_initializeLocalNotificationsSafely());
  }

  @override
  void dispose() {
    _ruleAlertSubscription?.close();
    _liveInterventionSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleAppResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final preferences = ref.watch(preferencesControllerProvider);

    if (!_didHandleInitialForeground &&
        preferences.asData?.value.hasCompletedOnboarding == true) {
      _didHandleInitialForeground = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_handleInitialAppForeground());
      });
    }

    return MaterialApp.router(
      title: 'LockdIn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }

  void _refreshBackendBackedViews() {
    ref.invalidate(dashboardAnalyticsProvider);
    ref.invalidate(trendsAnalyticsProvider);
    ref.invalidate(weeklySummaryProvider);
    ref.invalidate(ruleStatusesProvider);
  }

  Future<void> _refreshLiveEnforcementCacheSafely() async {
    try {
      await ref.read(liveInterventionProvider.notifier).refreshRuleStateCache();
    } catch (_) {
      // Avoid noisy lifecycle errors when the backend is temporarily unavailable.
    }
  }

  Future<void> _initializeLocalNotificationsSafely() async {
    try {
      await ref.read(localNotificationsProvider).initialize();
    } catch (_) {
      // Local notification setup should not block the app lifecycle.
    }
  }

  Future<void> _consumePendingNotificationNavigationSafely() async {
    if (_isPresentingLiveIntervention ||
        ref.read(liveInterventionProvider) != null) {
      return;
    }

    try {
      await ref.read(localNotificationsProvider).consumePendingNavigation();
      final route = await ref
          .read(liveEnforcementRepositoryProvider)
          .consumePendingLaunchNavigation();
      if (route == null || !mounted) {
        return;
      }

      final navigatorContext = ref
          .read(rootNavigatorKeyProvider)
          .currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) {
        return;
      }

      GoRouter.of(navigatorContext).go(route);
    } catch (_) {
      // Notification tap routing should stay best-effort.
    }
  }

  Future<void> _handleInitialAppForeground() async {
    final preferences = ref.read(preferencesControllerProvider).asData?.value;
    if (preferences == null || !preferences.hasCompletedOnboarding) {
      return;
    }

    await _configureNativeBackendSafely();
    await _flushPendingNativeUploadsSafely();
    await _maybeAutoSyncSafely();
    _refreshBackendBackedViews();
    await _refreshLiveEnforcementCacheSafely();
    await _flushPendingNativeEnforcementEventsSafely();
    await _checkPendingInterventionSafely();
    await _consumePendingNotificationNavigationSafely();
  }

  Future<void> _handleAppResume() async {
    final now = DateTime.now();
    if (_resumeRefreshInFlight) {
      return;
    }

    final lastResumeRefreshStartedAt = _lastResumeRefreshStartedAt;
    if (lastResumeRefreshStartedAt != null &&
        now.difference(lastResumeRefreshStartedAt) <
            const Duration(seconds: 2)) {
      return;
    }

    final preferences = ref.read(preferencesControllerProvider).asData?.value;
    if (preferences == null || !preferences.hasCompletedOnboarding) {
      return;
    }

    _resumeRefreshInFlight = true;
    _lastResumeRefreshStartedAt = now;
    try {
      await _configureNativeBackendSafely();
      final permissions = await _fetchPermissionsSafely();
      final queueSummary = await _flushPendingNativeUploadsSafely();
      _refreshBackendBackedViews();
      await _refreshLiveEnforcementCacheSafely();
      await _flushPendingNativeEnforcementEventsSafely();
      await _checkPendingInterventionSafely();
      await _consumePendingNotificationNavigationSafely();

      if (_shouldRunForegroundSync(
        permissions: permissions,
        queueSummary: queueSummary,
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _foregroundSyncSafely();
        _refreshBackendBackedViews();
        await _refreshLiveEnforcementCacheSafely();
        await _consumePendingNotificationNavigationSafely();
      }
    } finally {
      _resumeRefreshInFlight = false;
    }
  }

  Future<void> _configureNativeBackendSafely() async {
    try {
      await ref.read(liveEnforcementRepositoryProvider).cacheBackendBaseUrl();
      final tone = ref
          .read(preferencesControllerProvider)
          .asData
          ?.value
          .notificationTone;
      await ref
          .read(liveEnforcementRepositoryProvider)
          .cacheNotificationTone((tone ?? NotificationTone.professional).name);
    } catch (_) {
      // Native base URL caching should not break foreground refresh.
    }
  }

  Future<void> _flushPendingNativeEnforcementEventsSafely() async {
    try {
      await ref
          .read(liveInterventionProvider.notifier)
          .flushPendingNativeEnforcementEvents();
    } catch (_) {
      // Native enforcement event draining should stay best-effort.
    }
  }

  Future<DevicePermissions?> _fetchPermissionsSafely() async {
    try {
      return await ref.read(usageSyncRepositoryProvider).fetchPermissions();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _flushPendingNativeUploadsSafely() async {
    try {
      return await ref
          .read(liveEnforcementRepositoryProvider)
          .flushPendingUsageUploads();
    } catch (_) {
      // Resume should continue even if native queue flushing fails.
      return _emptyNativeUploadSummary;
    }
  }

  Future<void> _maybeAutoSyncSafely() async {
    try {
      await ref.read(usageSyncControllerProvider.notifier).maybeAutoSync();
    } catch (_) {
      // Initial foreground sync stays best-effort.
    }
  }

  Future<void> _foregroundSyncSafely() async {
    try {
      final permissions = await ref
          .read(usageSyncRepositoryProvider)
          .fetchPermissions();
      if (!permissions.usageAccess) {
        return;
      }

      await ref
          .read(usageSyncControllerProvider.notifier)
          .syncRecentUsage(days: 1);
    } catch (_) {
      // Fallback to backend refetch even if foreground sync fails.
    }
  }

  bool _shouldRunForegroundSync({
    required DevicePermissions? permissions,
    required Map<String, dynamic> queueSummary,
  }) {
    if (permissions == null || !permissions.usageAccess) {
      return false;
    }

    if (!permissions.accessibility) {
      return true;
    }

    final failedCount = (queueSummary['failedCount'] as num?)?.toInt() ?? 0;
    final pendingCount = (queueSummary['pendingCount'] as num?)?.toInt() ?? 0;

    return failedCount > 0 || pendingCount > 0;
  }

  static const Map<String, dynamic> _emptyNativeUploadSummary = {
    'uploadedCount': 0,
    'failedCount': 0,
    'pendingCount': 0,
    'lastError': '',
  };

  Future<void> _checkPendingInterventionSafely() async {
    try {
      await ref
          .read(liveInterventionProvider.notifier)
          .checkForPendingIntervention();
    } catch (_) {
      // Native intervention polling should stay best-effort.
    }
  }

  Future<void> _presentRuleAlert(RuleAlert alert) async {
    final navigatorContext = ref.read(rootNavigatorKeyProvider).currentContext;
    if (navigatorContext == null || !mounted) {
      return;
    }

    _isPresentingRuleAlert = true;
    final action = await showDialog<String>(
      context: navigatorContext,
      barrierDismissible: !alert.isCritical,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF242424),
          title: Text(alert.title),
          content: Text(alert.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('dismiss'),
              child: const Text('Got it'),
            ),
            if (alert.isCritical)
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('rules'),
                child: const Text('View Rules'),
              ),
          ],
        );
      },
    );

    if (mounted) {
      ref.read(ruleAlertProvider.notifier).clear();
    }

    _isPresentingRuleAlert = false;

    if (action == 'rules' && navigatorContext.mounted) {
      GoRouter.of(navigatorContext).go(AppRoutes.lockdownRules);
    }
  }

  Future<void> _presentLiveIntervention(
    PendingIntervention intervention,
  ) async {
    final navigatorContext = ref.read(rootNavigatorKeyProvider).currentContext;
    if (navigatorContext == null || !mounted) {
      return;
    }

    _isPresentingLiveIntervention = true;
    final action = await showDialog<String>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: Text(intervention.title),
          content: Text(intervention.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('stay'),
              child: const Text('Stay in LockdIn'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('rules'),
              child: const Text('View Rules'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      ref.read(liveInterventionProvider.notifier).clear();
    }

    _isPresentingLiveIntervention = false;

    if (action == 'stay') {
      try {
        await ref
            .read(liveInterventionProvider.notifier)
            .recordDismissedIntervention(
              intervention,
              action: 'stay_in_lockdin',
            );
      } catch (_) {
        // Keep the UI responsive even if dismissal logging fails.
      }
    }

    if (action == 'rules' && navigatorContext.mounted) {
      GoRouter.of(navigatorContext).go(AppRoutes.lockdownRules);
    }
  }
}
