import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../rules/data/rules_provider.dart';
import 'rule_alert_provider.dart';

final liveEnforcementRepositoryProvider = Provider<LiveEnforcementRepository>(
  (ref) => const LiveEnforcementRepository(),
);

final liveInterventionProvider =
    NotifierProvider<LiveInterventionController, PendingIntervention?>(
      LiveInterventionController.new,
    );

class PendingIntervention {
  const PendingIntervention({
    required this.ruleId,
    required this.appId,
    required this.appName,
    required this.usageDate,
    required this.usedMinutes,
    required this.limitMinutes,
    required this.status,
    required this.source,
  });

  final String ruleId;
  final String appId;
  final String appName;
  final String usageDate;
  final int usedMinutes;
  final int limitMinutes;
  final String status;
  final String source;

  String get title => '$appName is locked right now';

  String get message =>
      'You hit today\'s $limitMinutes-minute limit for $appName and are already at $usedMinutes minutes. Step away before jumping back in.';
}

class LiveInterventionController extends Notifier<PendingIntervention?> {
  bool _isChecking = false;

  @override
  PendingIntervention? build() => null;

  Future<List<RuleStatusData>> refreshRuleStateCache() async {
    final statuses = await ref.read(rulesRepositoryProvider).listRuleStatuses();
    await cacheRuleState(statuses);
    return statuses;
  }

  Future<void> cacheRuleState(List<RuleStatusData> statuses) async {
    await ref
        .read(liveEnforcementRepositoryProvider)
        .cacheRuleStatuses(statuses);
  }

  Future<void> checkForPendingIntervention() async {
    if (_isChecking) {
      return;
    }

    _isChecking = true;

    try {
      final pending = await ref
          .read(liveEnforcementRepositoryProvider)
          .consumePendingIntervention();
      if (pending == null) {
        return;
      }

      try {
        await ref
            .read(enforcementRepositoryProvider)
            .createEvent(
              ruleId: pending.ruleId,
              appId: pending.appId,
              eventType: 'intervention_blocked',
              usageDate: pending.usageDate,
              usedMinutes: pending.usedMinutes,
              limitMinutes: pending.limitMinutes,
              metadata: {'source': pending.source},
            );
      } catch (_) {
        // Keep the interruption flow working if event logging fails.
      }

      state = pending;
    } finally {
      _isChecking = false;
    }
  }

  void clear() {
    state = null;
  }
}

class LiveEnforcementRepository {
  const LiveEnforcementRepository();

  static const MethodChannel _channel = MethodChannel('lockdin/usage');

  Future<void> cacheBackendBaseUrl([String? baseUrl]) async {
    if (!_isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('cacheBackendBaseUrl', {
      'baseUrl': baseUrl ?? ApiConfig.baseUrl,
    });
  }

  Future<Map<String, dynamic>> flushPendingUsageUploads() async {
    if (!_isAndroid) {
      return const {
        'uploadedCount': 0,
        'failedCount': 0,
        'pendingCount': 0,
        'lastError': '',
      };
    }

    final response = await _channel.invokeMapMethod<String, dynamic>(
      'flushPendingUsageUploads',
    );
    return Map<String, dynamic>.from(response ?? const <String, dynamic>{});
  }

  Future<void> cacheRuleStatuses(List<RuleStatusData> statuses) async {
    if (!_isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('cacheRuleStatuses', {
      'statuses': statuses
          .map(
            (status) => {
              'ruleId': status.ruleId,
              'appId': status.appId,
              'appName': status.appName,
              'usageDate': status.usageDate,
              'enabled': status.enabled,
              'limitMinutes': status.limitMinutes,
              'usedMinutes': status.usedMinutes,
              'status': status.status,
            },
          )
          .toList(),
    });
  }

  Future<PendingIntervention?> consumePendingIntervention() async {
    if (!_isAndroid) {
      return null;
    }

    final json = await _channel.invokeMapMethod<String, dynamic>(
      'consumePendingIntervention',
    );
    if (json == null || json.isEmpty) {
      return null;
    }

    return PendingIntervention(
      ruleId: json['ruleId'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      usageDate: json['usageDate'] as String? ?? '',
      usedMinutes: (json['usedMinutes'] as num?)?.toInt() ?? 0,
      limitMinutes: (json['limitMinutes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'at_limit',
      source: json['source'] as String? ?? 'android_accessibility',
    );
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
