import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../analytics/data/analytics_provider.dart';
import '../../../usage/data/usage_sync_provider.dart';

/// Main dashboard screen showing usage overview.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(devicePermissionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardAnalyticsProvider);
    final permissionsAsync = ref.watch(devicePermissionsProvider);
    final syncAsync = ref.watch(usageSyncControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Spacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HLR-1', style: AppTextStyles.labelSmall),
              Spacing.verticalLg,
              _DashboardHeader(
                dateLabel: _formatDateLabel(DateTime.now()),
                onSettingsTap: () => context.push(AppRoutes.devicePermissions),
                onAnalyticsTap: () => context.push(AppRoutes.analytics),
              ),
              Spacing.verticalLg,
              _UsageSyncPanel(
                permissionsAsync: permissionsAsync,
                syncAsync: syncAsync,
              ),
              Spacing.verticalXxl,
              dashboardAsync.when(
                data: (analytics) => _DashboardContent(analytics: analytics),
                loading: () => const _DashboardStateCard(
                  message: 'Loading today\'s analytics from the backend.',
                ),
                error: (error, _) => _DashboardStateCard(
                  message: describeApiError(error),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(dashboardAnalyticsProvider),
                  isError: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageSyncPanel extends ConsumerWidget {
  const _UsageSyncPanel({
    required this.permissionsAsync,
    required this.syncAsync,
  });

  final AsyncValue<DevicePermissions> permissionsAsync;
  final AsyncValue<UsageSyncResult?> syncAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsController = ref.read(devicePermissionsProvider.notifier);
    final syncController = ref.read(usageSyncControllerProvider.notifier);

    return permissionsAsync.when(
      data: (permissions) {
        if (!permissions.isSupported) {
          return const AppCard(
            child: Text(
              'Android usage sync is only available on Android devices. Analytics on this device will stay backend-driven only.',
            ),
          );
        }

        final syncResult = syncAsync.asData?.value;
        final isSyncing = syncAsync.isLoading;

        Future<void> handlePrimaryAction() async {
          try {
            if (!permissions.usageAccess) {
              await permissionsController.openUsageAccessSettings();
              return;
            }

            final result = await syncController.syncRecentUsage(days: 3);
            if (!context.mounted) {
              return;
            }

            final message = result.collectedCount == 0
                ? 'No Android usage sessions were found to sync yet.'
                : 'Synced ${result.createdCount} new sessions and skipped ${result.duplicateCount} duplicates.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (error) {
            if (!context.mounted) {
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(describeApiError(error)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }

        Widget buildPrimaryButton() {
          return PrimaryButton(
            onPressed: handlePrimaryAction,
            label: permissions.usageAccess
                ? 'Sync Recent Usage'
                : 'Grant Usage Access',
            icon: permissions.usageAccess ? Icons.sync : Icons.open_in_new,
            isLoading: isSyncing,
          );
        }

        Widget buildSecondaryButton() {
          return SecondaryButton(
            onPressed: permissionsController.refresh,
            label: 'Refresh Access',
            icon: Icons.refresh,
          );
        }

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sync_outlined,
                    color: AppColors.purple400,
                    size: 20,
                  ),
                  Spacing.horizontalSm,
                  Text('Android Usage Sync', style: AppTextStyles.titleMedium),
                ],
              ),
              Spacing.verticalSm,
              Text(
                permissions.usageAccess
                    ? 'Usage Access is enabled. Sync up to three days of Android event history. Later syncs continue from the last successful watermark.'
                    : 'Grant Usage Access first so LockdIn can collect Android app sessions for analytics.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              if (syncResult != null) ...[
                Spacing.verticalMd,
                Text(
                  'Last sync: ${syncResult.createdCount} new, ${syncResult.duplicateCount} already imported, ${syncResult.collectedCount} total uploaded.',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              Spacing.verticalLg,
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 380) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildPrimaryButton(),
                        Spacing.verticalMd,
                        buildSecondaryButton(),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: buildPrimaryButton()),
                      Spacing.horizontalMd,
                      Expanded(child: buildSecondaryButton()),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const _DashboardStateCard(
        message: 'Checking Android Usage Access before syncing sessions.',
      ),
      error: (error, _) => _DashboardStateCard(
        message: describeApiError(error),
        actionLabel: 'Retry',
        onAction: permissionsController.refresh,
        isError: true,
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.analytics});

  final DashboardAnalyticsData analytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UsageCard(
          usageData: analytics.categoryBreakdown,
          totalMinutes: analytics.todayTotalMinutes,
          deltaFromYesterdayPercent: analytics.deltaFromYesterdayPercent,
        ),
        Spacing.verticalXxl,
        _CategoryBreakdown(
          usageData: analytics.categoryBreakdown,
          totalMinutes: analytics.todayTotalMinutes,
        ),
        Spacing.verticalXxl,
        PrimaryButton(
          onPressed: () => context.push(AppRoutes.lockdownRules),
          label: 'Add Rule',
          icon: Icons.add,
        ),
        Spacing.verticalXxl,
        _QuickActions(
          onTrendsTap: () => context.push(AppRoutes.trends),
          onRulesTap: () => context.push(AppRoutes.lockdownRules),
          onAccountabilityTap: () => context.push(AppRoutes.accountability),
        ),
        Spacing.verticalXxl,
        _WeeklyOverview(weeklyData: analytics.weeklyUsageHours),
        Spacing.verticalLg,
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.dateLabel,
    required this.onSettingsTap,
    required this.onAnalyticsTap,
  });

  final String dateLabel;
  final VoidCallback onSettingsTap;
  final VoidCallback onAnalyticsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard', style: AppTextStyles.headlineLarge),
            Spacing.verticalXs,
            Text(
              dateLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            AppIconButton(
              onPressed: onAnalyticsTap,
              icon: Icons.star_outline,
              iconColor: AppColors.purple400,
            ),
            Spacing.horizontalSm,
            AppIconButton(
              onPressed: onSettingsTap,
              icon: Icons.settings_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.usageData,
    required this.totalMinutes,
    required this.deltaFromYesterdayPercent,
  });

  final List<UsageData> usageData;
  final int totalMinutes;
  final int deltaFromYesterdayPercent;

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final sections = usageData.isEmpty
        ? [
            PieChartSectionData(
              color: AppColors.cardBackgroundLight,
              value: 1,
              radius: 15,
              showTitle: false,
            ),
          ]
        : usageData
              .map(
                (data) => PieChartSectionData(
                  color: data.color,
                  value: data.minutes.toDouble(),
                  radius: 15,
                  showTitle: false,
                ),
              )
              .toList();
    final trendColor = switch (deltaFromYesterdayPercent) {
      < 0 => AppColors.success,
      > 0 => AppColors.error,
      _ => AppColors.textSecondary,
    };
    final trendIcon = switch (deltaFromYesterdayPercent) {
      < 0 => Icons.trending_down,
      > 0 => Icons.trending_up,
      _ => Icons.horizontal_rule,
    };
    final trendText = totalMinutes == 0
        ? 'Waiting for your first usage sync'
        : switch (deltaFromYesterdayPercent) {
            < 0 => '${deltaFromYesterdayPercent.abs()}% less than yesterday',
            > 0 => '$deltaFromYesterdayPercent% more than yesterday',
            _ => 'Same as yesterday',
          };

    return GradientCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Screen Time',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Spacing.verticalSm,
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$hours',
                          style: AppTextStyles.statLarge,
                        ),
                        TextSpan(text: 'h ', style: AppTextStyles.statUnit),
                        TextSpan(
                          text: '$minutes',
                          style: AppTextStyles.statLarge,
                        ),
                        TextSpan(text: 'm', style: AppTextStyles.statUnit),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 96,
                height: 96,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: sections,
                  ),
                ),
              ),
            ],
          ),
          Spacing.verticalLg,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: trendColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Spacing.horizontalSm,
                  Text(
                    trendText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Icon(trendIcon, color: trendColor, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.usageData,
    required this.totalMinutes,
  });

  final List<UsageData> usageData;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By Category',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Spacing.verticalMd,
        if (usageData.isEmpty)
          const AppCard(
            child: Text(
              'No category usage yet. Sync Android usage to populate this breakdown.',
            ),
          )
        else
          ...usageData.map(
            (data) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CategoryItem(
                data: data,
                percentage: totalMinutes == 0 ? 0 : data.minutes / totalMinutes,
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({required this.data, required this.percentage});

  final UsageData data;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: data.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Spacing.horizontalMd,
                  Text(data.name, style: AppTextStyles.titleMedium),
                ],
              ),
              Text(
                data.formattedTime,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          Spacing.verticalSm,
          AppProgressBar(value: percentage, color: data.color),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onTrendsTap,
    required this.onRulesTap,
    required this.onAccountabilityTap,
  });

  final VoidCallback onTrendsTap;
  final VoidCallback onRulesTap;
  final VoidCallback onAccountabilityTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.bar_chart,
            label: 'Trends',
            onTap: onTrendsTap,
          ),
        ),
        Spacing.horizontalMd,
        Expanded(
          child: _QuickActionButton(
            icon: Icons.lock_outline,
            label: 'Rules',
            onTap: onRulesTap,
          ),
        ),
        Spacing.horizontalMd,
        Expanded(
          child: _QuickActionButton(
            icon: Icons.people_outline,
            label: 'Accountability',
            onTap: onAccountabilityTap,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.purple400, size: 24),
          Spacing.verticalSm,
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyOverview extends StatelessWidget {
  const _WeeklyOverview({required this.weeklyData});

  final List<double> weeklyData;

  @override
  Widget build(BuildContext context) {
    final normalizedData = [
      for (var index = 0; index < 7; index++)
        index < weeklyData.length ? weeklyData[index] : 0.0,
    ];
    final maxValue = normalizedData.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final totalHours = normalizedData.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final dayLabels = _recentDayLabels();

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Week', style: AppTextStyles.titleMedium),
              Text(
                _formatHoursAndMinutes(totalHours),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          Spacing.verticalLg,
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(normalizedData.length, (index) {
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: VerticalBar(
                          value: normalizedData[index],
                          maxValue: maxValue == 0 ? 1 : maxValue,
                        ),
                      ),
                      Spacing.verticalSm,
                      Text(dayLabels[index], style: AppTextStyles.labelSmall),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStateCard extends StatelessWidget {
  const _DashboardStateCard({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isError)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.error_outline, color: AppColors.error),
              Spacing.horizontalMd,
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isError ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            Spacing.verticalLg,
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _formatDateLabel(DateTime date) {
  const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${weekdayNames[date.weekday - 1]}, ${monthNames[date.month - 1]} ${date.day}';
}

List<String> _recentDayLabels() {
  const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final today = DateTime.now();

  return List.generate(7, (index) {
    final day = today.subtract(Duration(days: 6 - index));
    return letters[day.weekday - 1];
  });
}

String _formatHoursAndMinutes(double totalHours) {
  final totalMinutes = (totalHours * 60).round();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) {
    return '${minutes}m total';
  }
  if (minutes == 0) {
    return '${hours}h total';
  }
  return '${hours}h ${minutes}m total';
}
