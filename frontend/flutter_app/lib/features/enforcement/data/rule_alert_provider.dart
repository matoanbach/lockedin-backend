import 'package:dio/dio.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/models.dart';
import '../../preferences/data/preferences_provider.dart';
import '../../rules/data/rules_provider.dart';

final enforcementRepositoryProvider = Provider<EnforcementRepository>((ref) {
  return EnforcementRepository(ref.watch(dioProvider));
});

final ruleAlertProvider = NotifierProvider<RuleAlertController, RuleAlert?>(
  RuleAlertController.new,
);

class RuleAlert {
  const RuleAlert({
    required this.ruleId,
    required this.appName,
    required this.status,
    required this.title,
    required this.message,
    required this.isCritical,
  });

  final String ruleId;
  final String appName;
  final String status;
  final String title;
  final String message;
  final bool isCritical;
}

class RuleAlertController extends Notifier<RuleAlert?> {
  @override
  RuleAlert? build() => null;

  Future<void> evaluateAndQueueNextAlert({
    List<RuleStatusData>? statuses,
  }) async {
    final ruleStatuses =
        statuses ?? await ref.read(rulesRepositoryProvider).listRuleStatuses();
    final preferences = await SharedPreferences.getInstance();
    final sortedStatuses = [...ruleStatuses]..sort(_comparePriority);

    for (final status in sortedStatuses) {
      if (!status.enabled) {
        continue;
      }

      final eventType = _eventTypeForStatus(status.status);
      if (eventType == null) {
        continue;
      }

      final dedupeKey = _alertDedupeKey(status, eventType);
      if (preferences.getBool(dedupeKey) == true) {
        continue;
      }

      final tone =
          ref
              .read(preferencesControllerProvider)
              .asData
              ?.value
              .notificationTone ??
          NotificationTone.professional;
      final alert = _buildAlert(status, tone);

      try {
        await ref
            .read(enforcementRepositoryProvider)
            .createEvent(
              ruleId: status.ruleId,
              appId: status.appId,
              eventType: eventType,
              usageDate: status.usageDate,
              usedMinutes: status.usedMinutes,
              limitMinutes: status.limitMinutes,
              metadata: const {'source': 'app_sync'},
            );
      } catch (_) {
        // Keep the user-facing alert path working even if event logging fails.
      }

      await preferences.setBool(dedupeKey, true);
      final notificationShown = await ref
          .read(localNotificationsProvider)
          .showWarning(
            notificationId: Object.hash(
              status.ruleId,
              status.usageDate,
              eventType,
            ).hashCode.abs(),
            title: alert.title,
            body: alert.message,
            payload: jsonEncode({
              'route': AppRoutes.lockdownRules,
              'ruleId': status.ruleId,
              'appId': status.appId,
            }),
          );
      state = notificationShown ? null : alert;
      return;
    }
  }

  void clear() {
    state = null;
  }

  int _comparePriority(RuleStatusData left, RuleStatusData right) {
    final priorityDifference =
        _priorityForStatus(right.status) - _priorityForStatus(left.status);
    if (priorityDifference != 0) {
      return priorityDifference;
    }

    return right.usedMinutes.compareTo(left.usedMinutes);
  }

  int _priorityForStatus(String status) {
    return switch (status) {
      'over_limit' => 3,
      'at_limit' => 2,
      'approaching_limit' => 1,
      _ => 0,
    };
  }

  String? _eventTypeForStatus(String status) {
    return switch (status) {
      'approaching_limit' => 'warning_approaching_limit',
      'at_limit' => 'warning_limit_reached',
      'over_limit' => 'warning_limit_reached',
      _ => null,
    };
  }

  String _alertDedupeKey(RuleStatusData status, String eventType) {
    return 'rule_alert.${status.ruleId}.${status.usageDate}.$eventType';
  }

  RuleAlert _buildAlert(RuleStatusData status, NotificationTone tone) {
    final message = _messageForTone(status, tone);

    return switch (status.status) {
      'over_limit' => RuleAlert(
        ruleId: status.ruleId,
        appName: status.appName,
        status: status.status,
        title: '${status.appName} is over limit',
        message: message,
        isCritical: true,
      ),
      'at_limit' => RuleAlert(
        ruleId: status.ruleId,
        appName: status.appName,
        status: status.status,
        title: '${status.appName} reached its limit',
        message: message,
        isCritical: true,
      ),
      _ => RuleAlert(
        ruleId: status.ruleId,
        appName: status.appName,
        status: status.status,
        title: '${status.appName} is approaching its limit',
        message: message,
        isCritical: false,
      ),
    };
  }

  String _messageForTone(RuleStatusData status, NotificationTone tone) {
    return switch ((status.status, tone)) {
      ('approaching_limit', NotificationTone.fun) =>
        'Heads up: only ${status.remainingMinutes} minutes left before ${status.appName} hits today\'s limit.',
      ('approaching_limit', NotificationTone.edgy) =>
        '${status.remainingMinutes} minutes left. ${status.appName} is almost out of runway.',
      ('approaching_limit', _) =>
        '${status.remainingMinutes} minutes remain before you hit today\'s ${status.limitMinutes}-minute limit for ${status.appName}.',
      ('at_limit', NotificationTone.fun) =>
        'You just hit today\'s ${status.limitMinutes}-minute limit for ${status.appName}. Time to step out for a reset.',
      ('at_limit', NotificationTone.edgy) =>
        'Limit reached. Close ${status.appName} before it steals more of your day.',
      ('at_limit', _) =>
        'You have hit today\'s ${status.limitMinutes}-minute limit for ${status.appName}.',
      ('over_limit', NotificationTone.fun) =>
        'You\'re already at ${status.usedMinutes} minutes on ${status.appName}. Take the win by putting it down now.',
      ('over_limit', NotificationTone.edgy) =>
        '${status.appName} is already over the line at ${status.usedMinutes} minutes. Stop scrolling.',
      _ =>
        'You have used ${status.usedMinutes} minutes today against a ${status.limitMinutes}-minute rule for ${status.appName}.',
    };
  }
}

class EnforcementRepository {
  EnforcementRepository(this._dio);

  final Dio _dio;

  Future<void> createEvent({
    required String ruleId,
    required String appId,
    required String eventType,
    required String usageDate,
    required int usedMinutes,
    required int limitMinutes,
    required Map<String, Object?> metadata,
  }) async {
    await _dio.post(
      '/api/v1/enforcement/events',
      data: {
        'ruleId': ruleId,
        'appId': appId,
        'eventType': eventType,
        'usageDate': usageDate,
        'usedMinutes': usedMinutes,
        'limitMinutes': limitMinutes,
        'metadata': metadata,
      },
    );
  }
}
