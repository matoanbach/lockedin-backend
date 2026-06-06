import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/theme/app_colors.dart';

/// Provider for usage data displayed on dashboard.
final usageDataProvider = Provider<List<UsageData>>((ref) {
  return const [
    UsageData(name: 'Social', minutes: 125, color: AppColors.chart1),
    UsageData(name: 'Entertainment', minutes: 85, color: AppColors.chart2),
    UsageData(name: 'Productivity', minutes: 42, color: AppColors.chart3),
    UsageData(name: 'Other', minutes: 28, color: AppColors.chart4),
  ];
});

/// Total usage minutes.
final totalMinutesProvider = Provider<int>((ref) {
  final data = ref.watch(usageDataProvider);
  return data.fold(0, (sum, item) => sum + item.minutes);
});

/// Weekly usage data.
final weeklyUsageProvider = Provider<List<double>>((ref) {
  return [3.2, 4.5, 2.8, 5.1, 4.2, 6.3, 5.8];
});

/// Provider for lockdown rules.
final lockdownRulesProvider =
    NotifierProvider<LockdownRulesNotifier, List<LockdownRule>>(
  LockdownRulesNotifier.new,
);

class LockdownRulesNotifier extends Notifier<List<LockdownRule>> {
  @override
  List<LockdownRule> build() => [
    const LockdownRule(
      id: '1',
      appName: 'Instagram',
      icon: Icons.camera_alt,
      limitMinutes: 120,
      enabled: true,
      color: AppColors.instagram,
    ),
    const LockdownRule(
      id: '2',
      appName: 'YouTube',
      icon: Icons.play_circle_filled,
      limitMinutes: 90,
      enabled: true,
      color: AppColors.youtube,
    ),
    const LockdownRule(
      id: '3',
      appName: 'Messages',
      icon: Icons.message,
      limitMinutes: 60,
      enabled: false,
      color: AppColors.messages,
    ),
  ];

  void toggleRule(String id) {
    state = [
      for (final rule in state)
        if (rule.id == id) rule.copyWith(enabled: !rule.enabled) else rule
    ];
  }

  void addRule(LockdownRule rule) {
    state = [...state, rule];
  }

  void removeRule(String id) {
    state = state.where((rule) => rule.id != id).toList();
  }

  void updateLimit(String id, int minutes) {
    state = [
      for (final rule in state)
        if (rule.id == id) rule.copyWith(limitMinutes: minutes) else rule
    ];
  }
}
