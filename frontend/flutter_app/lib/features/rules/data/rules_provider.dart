import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart';

final rulesRepositoryProvider = Provider<RulesRepository>((ref) {
  return RulesRepository(ref.watch(dioProvider));
});

final lockdownRulesProvider = AsyncNotifierProvider<LockdownRulesController,
    List<LockdownRule>>(LockdownRulesController.new);

class LockdownRulesController extends AsyncNotifier<List<LockdownRule>> {
  RulesRepository get _repository => ref.read(rulesRepositoryProvider);

  @override
  Future<List<LockdownRule>> build() {
    return _repository.listRules();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.listRules);
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
}

class RulesRepository {
  RulesRepository(this._dio);

  final Dio _dio;

  Future<List<LockdownRule>> listRules() async {
    final response = await _dio.get('/api/v1/rules');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => _ruleFromJson(Map<String, dynamic>.from(item as Map)))
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
        'appName':? appName,
        'limitMinutes':? limitMinutes,
        'enabled':? enabled,
      },
    );

    return _ruleFromJson(Map<String, dynamic>.from(response.data as Map));
  }
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
  final normalized = '$appId $appName'.toLowerCase();

  if (normalized.contains('instagram')) {
    return Icons.camera_alt;
  }
  if (normalized.contains('youtube')) {
    return Icons.play_circle_filled;
  }
  if (normalized.contains('message') || normalized.contains('messaging')) {
    return Icons.message;
  }
  if (normalized.contains('spotify')) {
    return Icons.music_note;
  }
  if (normalized.contains('tiktok')) {
    return Icons.video_collection;
  }

  return Icons.apps;
}

Color _colorForApp(String appId, String appName) {
  final normalized = '$appId $appName'.toLowerCase();

  if (normalized.contains('instagram')) {
    return AppColors.instagram;
  }
  if (normalized.contains('youtube')) {
    return AppColors.youtube;
  }
  if (normalized.contains('message') || normalized.contains('messaging')) {
    return AppColors.messages;
  }
  if (normalized.contains('spotify')) {
    return AppColors.success;
  }
  if (normalized.contains('tiktok')) {
    return AppColors.warning;
  }

  return AppColors.chart1;
}
