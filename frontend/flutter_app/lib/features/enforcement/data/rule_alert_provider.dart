import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
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

      final dedupeKey = _alertDedupeKey(status);
      if (preferences.getBool(dedupeKey) == true) {
        continue;
      }

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
      state = _buildAlert(status);
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
      'over_limit' => 'intervention_blocked',
      _ => null,
    };
  }

  String _alertDedupeKey(RuleStatusData status) {
    return 'rule_alert.${status.ruleId}.${status.usageDate}.${status.status}';
  }

  RuleAlert _buildAlert(RuleStatusData status) {
    return switch (status.status) {
      'over_limit' => RuleAlert(
        ruleId: status.ruleId,
        appName: status.appName,
        status: status.status,
        title: '${status.appName} is over limit',
        message:
            'You have used ${status.usedMinutes} minutes today against a ${status.limitMinutes}-minute rule. Step away or tighten the rule if this app keeps pulling you in.',
        isCritical: true,
      ),
      'at_limit' => RuleAlert(
        ruleId: status.ruleId,
        appName: status.appName,
        status: status.status,
        title: '${status.appName} reached its limit',
        message:
            'You have hit today\'s ${status.limitMinutes}-minute limit for ${status.appName}.',
        isCritical: true,
      ),
      _ => RuleAlert(
        ruleId: status.ruleId,
        appName: status.appName,
        status: status.status,
        title: '${status.appName} is approaching its limit',
        message:
            '${status.remainingMinutes} minutes remain before you hit today\'s limit for ${status.appName}.',
        isCritical: false,
      ),
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
