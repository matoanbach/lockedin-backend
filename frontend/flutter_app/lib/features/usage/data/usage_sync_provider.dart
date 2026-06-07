import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../analytics/data/analytics_provider.dart';
import '../../enforcement/data/live_intervention_provider.dart';
import '../../enforcement/data/rule_alert_provider.dart';
import '../../rules/data/rules_provider.dart';

final usageSyncRepositoryProvider = Provider<UsageSyncRepository>((ref) {
  return UsageSyncRepository(ref.watch(dioProvider));
});

final devicePermissionsProvider =
    AsyncNotifierProvider<DevicePermissionsController, DevicePermissions>(
      DevicePermissionsController.new,
    );

final usageSyncControllerProvider =
    AsyncNotifierProvider<UsageSyncController, UsageSyncResult?>(
      UsageSyncController.new,
    );

class DevicePermissions {
  const DevicePermissions({
    required this.isSupported,
    required this.usageAccess,
    required this.notifications,
    required this.accessibility,
    required this.notificationDiagnostics,
  });

  final bool isSupported;
  final bool usageAccess;
  final bool notifications;
  final bool accessibility;
  final NotificationDiagnostics notificationDiagnostics;

  bool get readyToContinue => !isSupported || usageAccess;
}

class NotificationDiagnostics {
  const NotificationDiagnostics({
    required this.appEnabled,
    required this.channelId,
    required this.channelExists,
    required this.channelEnabled,
    required this.channelImportance,
    required this.channelImportanceLabel,
  });

  final bool appEnabled;
  final String channelId;
  final bool channelExists;
  final bool channelEnabled;
  final int channelImportance;
  final String channelImportanceLabel;

  bool get isHealthy => appEnabled && channelExists && channelEnabled;

  String get summary {
    if (!appEnabled) {
      return 'App notifications are disabled in Android settings.';
    }
    if (!channelExists) {
      return 'Warning channel has not been created yet.';
    }
    if (!channelEnabled) {
      return 'LockdIn warnings channel is blocked or silent.';
    }
    return 'Warning channel is enabled with $channelImportanceLabel importance.';
  }
}

class UsageSyncResult {
  const UsageSyncResult({
    required this.collectedCount,
    required this.createdCount,
    required this.duplicateCount,
    required this.syncedAt,
  });

  final int collectedCount;
  final int createdCount;
  final int duplicateCount;
  final DateTime syncedAt;

  bool get hasNewEvents => createdCount > 0;
}

class DevicePermissionsController extends AsyncNotifier<DevicePermissions> {
  UsageSyncRepository get _repository => ref.read(usageSyncRepositoryProvider);

  @override
  Future<DevicePermissions> build() {
    return _repository.fetchPermissions();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.fetchPermissions);
  }

  Future<void> openUsageAccessSettings() {
    return _repository.openUsageAccessSettings();
  }

  Future<void> openNotificationSettings() {
    return _repository.openNotificationSettings();
  }

  Future<void> openNotificationAccess() async {
    final notifications = ref.read(localNotificationsProvider);
    await notifications.initialize();

    if (await notifications.areNotificationsEnabled()) {
      await _repository.openNotificationSettings();
      return;
    }

    final granted = await notifications.requestPermission();
    await refresh();
    if (!granted) {
      await _repository.openNotificationSettings();
      await refresh();
    }
  }

  Future<void> openAccessibilitySettings() {
    return _repository.openAccessibilitySettings();
  }

  Future<bool> sendTestWarningNotification() async {
    final shown = await _repository.sendTestWarningNotification();
    await refresh();
    return shown;
  }
}

class UsageSyncController extends AsyncNotifier<UsageSyncResult?> {
  UsageSyncRepository get _repository => ref.read(usageSyncRepositoryProvider);
  bool _syncInFlight = false;

  @override
  Future<UsageSyncResult?> build() async => null;

  Future<UsageSyncResult> syncRecentUsage({int days = 14}) async {
    if (_syncInFlight) {
      throw StateError('A usage sync is already in progress.');
    }

    _syncInFlight = true;
    state = const AsyncLoading();

    try {
      final result = await _repository.syncRecentUsage(days: days);
      state = AsyncData(result);
      _refreshAnalytics();
      final statuses = await ref
          .read(liveInterventionProvider.notifier)
          .refreshRuleStateCache();
      final permissions = await _repository.fetchPermissions();
      if (!(permissions.accessibility && permissions.notifications)) {
        await ref
            .read(ruleAlertProvider.notifier)
            .evaluateAndQueueNextAlert(statuses: statuses);
      }
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    } finally {
      _syncInFlight = false;
    }
  }

  Future<UsageSyncResult?> maybeAutoSync({
    int days = 14,
    Duration cooldown = const Duration(minutes: 1),
  }) async {
    if (_syncInFlight) {
      return null;
    }

    _syncInFlight = true;

    try {
      final result = await _repository.maybeAutoSync(
        days: days,
        cooldown: cooldown,
      );
      if (result == null) {
        return null;
      }

      state = AsyncData(result);
      _refreshAnalytics();
      final statuses = await ref
          .read(liveInterventionProvider.notifier)
          .refreshRuleStateCache();
      final permissions = await _repository.fetchPermissions();
      if (!(permissions.accessibility && permissions.notifications)) {
        await ref
            .read(ruleAlertProvider.notifier)
            .evaluateAndQueueNextAlert(statuses: statuses);
      }
      return result;
    } catch (_) {
      return null;
    } finally {
      _syncInFlight = false;
    }
  }

  void _refreshAnalytics() {
    ref.invalidate(dashboardAnalyticsProvider);
    ref.invalidate(trendsAnalyticsProvider);
    ref.invalidate(weeklySummaryProvider);
    ref.invalidate(ruleStatusesProvider);
  }
}

class UsageSyncRepository {
  UsageSyncRepository(this._dio);

  final Dio _dio;
  static const MethodChannel _channel = MethodChannel('lockdin/usage');
  static const String _lastSuccessfulSyncAtKey =
      'usage_sync.last_successful_at';

  Future<DevicePermissions> fetchPermissions() async {
    if (!_isAndroid) {
      return const DevicePermissions(
        isSupported: false,
        usageAccess: false,
        notifications: false,
        accessibility: false,
        notificationDiagnostics: NotificationDiagnostics(
          appEnabled: false,
          channelId: 'lockdin_warnings',
          channelExists: false,
          channelEnabled: false,
          channelImportance: 0,
          channelImportanceLabel: 'unavailable',
        ),
      );
    }

    final response = await _channel.invokeMapMethod<String, dynamic>(
      'getPermissionStatus',
    );
    final json = response ?? const <String, dynamic>{};

    return DevicePermissions(
      isSupported: true,
      usageAccess: json['usageAccess'] == true,
      notifications: json['notifications'] == true,
      accessibility: json['accessibility'] == true,
      notificationDiagnostics: _notificationDiagnosticsFromJson(
        json['notificationDiagnostics'],
      ),
    );
  }

  NotificationDiagnostics _notificationDiagnosticsFromJson(Object? raw) {
    final json = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    return NotificationDiagnostics(
      appEnabled: json['appEnabled'] == true,
      channelId: json['channelId'] as String? ?? 'lockdin_warnings',
      channelExists: json['channelExists'] == true,
      channelEnabled: json['channelEnabled'] == true,
      channelImportance: (json['channelImportance'] as num?)?.toInt() ?? 0,
      channelImportanceLabel:
          json['channelImportanceLabel'] as String? ?? 'unknown',
    );
  }

  Future<void> openUsageAccessSettings() async {
    if (!_isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  Future<void> openNotificationSettings() async {
    if (!_isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  Future<void> openAccessibilitySettings() async {
    if (!_isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  Future<bool> sendTestWarningNotification() async {
    if (!_isAndroid) {
      return false;
    }

    final shown = await _channel.invokeMethod<bool>(
      'sendTestWarningNotification',
    );
    return shown == true;
  }

  Future<UsageSyncResult> syncRecentUsage({int days = 14}) async {
    final result = await _performUsageSync(days: days);
    await _storeLastSuccessfulSyncAt(result.syncedAt);
    return result;
  }

  Future<UsageSyncResult?> maybeAutoSync({
    int days = 14,
    Duration cooldown = const Duration(minutes: 1),
  }) async {
    if (!_isAndroid) {
      return null;
    }

    final permissions = await fetchPermissions();
    if (!permissions.usageAccess) {
      return null;
    }

    final preferences = await SharedPreferences.getInstance();
    final lastSyncMillis = preferences.getInt(_lastSuccessfulSyncAtKey);
    if (lastSyncMillis != null) {
      final lastSyncAt = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
      if (DateTime.now().difference(lastSyncAt) < cooldown) {
        return null;
      }
    }

    final result = await _performUsageSync(days: days);
    await _storeLastSuccessfulSyncAt(result.syncedAt);
    return result;
  }

  Future<UsageSyncResult> _performUsageSync({required int days}) async {
    if (!_isAndroid) {
      throw UnsupportedError(
        'Android usage sync is only available on Android devices.',
      );
    }

    final permissions = await fetchPermissions();
    if (!permissions.usageAccess) {
      throw StateError(
        'Grant Usage Access before syncing Android app sessions.',
      );
    }

    final rawEvents =
        await _channel.invokeListMethod<dynamic>('collectUsageEvents', {
          'days': days,
        }) ??
        const <dynamic>[];
    final events = rawEvents
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (events.isEmpty) {
      return UsageSyncResult(
        collectedCount: 0,
        createdCount: 0,
        duplicateCount: 0,
        syncedAt: DateTime.now(),
      );
    }

    final response = await _dio.post(
      '/api/v1/usage/events',
      data: {'events': events},
    );
    final json = Map<String, dynamic>.from(response.data as Map);

    return UsageSyncResult(
      collectedCount: (json['receivedCount'] as num?)?.toInt() ?? events.length,
      createdCount: (json['createdCount'] as num?)?.toInt() ?? 0,
      duplicateCount: (json['duplicateCount'] as num?)?.toInt() ?? 0,
      syncedAt: DateTime.now(),
    );
  }

  Future<void> _storeLastSuccessfulSyncAt(DateTime syncedAt) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _lastSuccessfulSyncAtKey,
      syncedAt.millisecondsSinceEpoch,
    );
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
