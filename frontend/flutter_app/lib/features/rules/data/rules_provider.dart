import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart';

class KnownRuleApp {
  const KnownRuleApp({
    required this.displayName,
    required this.appId,
    this.aliasAppIds = const <String>[],
    required this.icon,
    required this.color,
  });

  final String displayName;
  final String appId;
  final List<String> aliasAppIds;
  final IconData icon;
  final Color color;
}

const knownRuleApps = <KnownRuleApp>[
  KnownRuleApp(
    displayName: 'Instagram',
    appId: 'com.instagram.android',
    icon: Icons.camera_alt,
    color: AppColors.instagram,
  ),
  KnownRuleApp(
    displayName: 'YouTube',
    appId: 'com.google.android.youtube',
    aliasAppIds: ['com.youtube.android'],
    icon: Icons.play_circle_filled,
    color: AppColors.youtube,
  ),
  KnownRuleApp(
    displayName: 'Messages',
    appId: 'com.google.android.apps.messaging',
    icon: Icons.message,
    color: AppColors.messages,
  ),
  KnownRuleApp(
    displayName: 'Spotify',
    appId: 'com.spotify.music',
    icon: Icons.music_note,
    color: AppColors.success,
  ),
  KnownRuleApp(
    displayName: 'TikTok',
    appId: 'com.zhiliaoapp.musically',
    icon: Icons.video_collection,
    color: AppColors.warning,
  ),
];

final rulesRepositoryProvider = Provider<RulesRepository>((ref) {
  return RulesRepository(ref.watch(dioProvider));
});

final lockdownRulesProvider =
    AsyncNotifierProvider<LockdownRulesController, List<LockdownRule>>(
      LockdownRulesController.new,
    );

final ruleStatusesProvider = FutureProvider<List<RuleStatusData>>((ref) {
  return ref.watch(rulesRepositoryProvider).listRuleStatuses();
});

class RuleStatusData {
  const RuleStatusData({
    required this.ruleId,
    required this.appId,
    required this.appName,
    required this.usageDate,
    required this.enabled,
    required this.limitMinutes,
    required this.usedMinutes,
    required this.remainingMinutes,
    required this.progressPercent,
    required this.status,
    required this.isBlockedNow,
  });

  final String ruleId;
  final String appId;
  final String appName;
  final String usageDate;
  final bool enabled;
  final int limitMinutes;
  final int usedMinutes;
  final int remainingMinutes;
  final int progressPercent;
  final String status;
  final bool isBlockedNow;

  double get progressValue => (progressPercent / 100).clamp(0.0, 1.0);

  String get formattedUsage {
    final usedHours = usedMinutes ~/ 60;
    final usedRemainderMinutes = usedMinutes % 60;
    final limitHours = limitMinutes ~/ 60;
    final limitRemainderMinutes = limitMinutes % 60;

    String formatTime(int hours, int minutes) {
      if (hours == 0) {
        return '${minutes}m';
      }
      if (minutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${minutes}m';
    }

    return '${formatTime(usedHours, usedRemainderMinutes)} / ${formatTime(limitHours, limitRemainderMinutes)}';
  }
}

class LockdownRulesController extends AsyncNotifier<List<LockdownRule>> {
  RulesRepository get _repository => ref.read(rulesRepositoryProvider);

  @override
  Future<List<LockdownRule>> build() {
    return _repository.listRules();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.listRules);
    ref.invalidate(ruleStatusesProvider);
  }

  Future<void> createRule({
    required String appId,
    required String appName,
    required int limitMinutes,
    required bool enabled,
  }) async {
    await _repository.createRule(
      appId: appId,
      appName: appName,
      limitMinutes: limitMinutes,
      enabled: enabled,
    );
    await refresh();
  }

  Future<void> toggleRule(String ruleId) async {
    final rules = state.asData?.value;
    if (rules == null) {
      return;
    }

    final rule = rules.where((item) => item.id == ruleId).firstOrNull;
    if (rule == null) {
      return;
    }

    await _repository.updateRule(ruleId, enabled: !rule.enabled);
    await refresh();
  }

  Future<void> updateRule({
    required String ruleId,
    String? appName,
    int? limitMinutes,
    bool? enabled,
  }) async {
    await _repository.updateRule(
      ruleId,
      appName: appName,
      limitMinutes: limitMinutes,
      enabled: enabled,
    );
    await refresh();
  }

  Future<void> deleteRule(String ruleId) async {
    await _repository.deleteRule(ruleId);
    await refresh();
  }
}

class RulesRepository {
  RulesRepository(this._dio);

  final Dio _dio;

  Future<LockdownRule> createRule({
    required String appId,
    required String appName,
    required int limitMinutes,
    required bool enabled,
  }) async {
    final response = await _dio.post(
      '/api/v1/rules',
      data: {
        'appId': appId,
        'appName': appName,
        'limitMinutes': limitMinutes,
        'enabled': enabled,
      },
    );

    return _ruleFromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<LockdownRule>> listRules() async {
    final response = await _dio.get('/api/v1/rules');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => _ruleFromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<RuleStatusData>> listRuleStatuses() async {
    final response = await _dio.get('/api/v1/rules/status');
    final data = response.data as List<dynamic>;

    return data
        .map(
          (item) => _ruleStatusFromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<LockdownRule> updateRule(
    String ruleId, {
    String? appName,
    int? limitMinutes,
    bool? enabled,
  }) async {
    final response = await _dio.patch(
      '/api/v1/rules/$ruleId',
      data: {
        'appName': ?appName,
        'limitMinutes': ?limitMinutes,
        'enabled': ?enabled,
      },
    );

    return _ruleFromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteRule(String ruleId) async {
    await _dio.delete('/api/v1/rules/$ruleId');
  }
}

RuleStatusData _ruleStatusFromJson(Map<String, dynamic> json) {
  return RuleStatusData(
    ruleId: json['ruleId'] as String,
    appId: json['appId'] as String,
    appName: json['appName'] as String,
    usageDate: json['usageDate'] as String,
    enabled: json['enabled'] as bool,
    limitMinutes: json['limitMinutes'] as int,
    usedMinutes: json['usedMinutes'] as int,
    remainingMinutes: json['remainingMinutes'] as int,
    progressPercent: json['progressPercent'] as int,
    status: json['status'] as String,
    isBlockedNow: json['isBlockedNow'] as bool,
  );
}

LockdownRule _ruleFromJson(Map<String, dynamic> json) {
  final appId = json['appId'] as String;
  final appName = json['appName'] as String;

  return LockdownRule(
    id: json['id'] as String,
    appId: appId,
    appName: appName,
    icon: _iconForApp(appId, appName),
    limitMinutes: json['limitMinutes'] as int,
    enabled: json['enabled'] as bool,
    color: _colorForApp(appId, appName),
  );
}

IconData _iconForApp(String appId, String appName) {
  return _knownRuleAppFor(appId, appName)?.icon ?? Icons.apps;
}

Color _colorForApp(String appId, String appName) {
  return _knownRuleAppFor(appId, appName)?.color ?? AppColors.chart1;
}

KnownRuleApp? knownRuleAppFor(String appId, String appName) {
  return _knownRuleAppFor(appId, appName);
}

KnownRuleApp? _knownRuleAppFor(String appId, String appName) {
  final normalized = '$appId $appName'.toLowerCase();

  for (final app in knownRuleApps) {
    if (normalized.contains(app.appId.toLowerCase()) ||
        app.aliasAppIds.any(
          (alias) => normalized.contains(alias.toLowerCase()),
        ) ||
        normalized.contains(app.displayName.toLowerCase())) {
      return app;
    }
  }

  return null;
}
