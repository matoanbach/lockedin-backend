import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/providers/dashboard_provider.dart';

/// Main dashboard screen showing usage overview.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageData = ref.watch(usageDataProvider);
    final totalMinutes = ref.watch(totalMinutesProvider);
    final weeklyData = ref.watch(weeklyUsageProvider);

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Spacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HLR Label
              Text('HLR-1', style: AppTextStyles.labelSmall),
              Spacing.verticalLg,

              // Header with actions
              _DashboardHeader(
                onSettingsTap: () => context.push(AppRoutes.notificationSettings),
                onAnalyticsTap: () => context.push(AppRoutes.analytics),
              ),
              Spacing.verticalXxl,

              // Today's Usage Card
              _UsageCard(
                hours: hours,
                minutes: minutes,
                usageData: usageData,
                totalMinutes: totalMinutes,
              ),
              Spacing.verticalXxl,

              // Category Breakdown
              _CategoryBreakdown(
                usageData: usageData,
                totalMinutes: totalMinutes,
              ),
              Spacing.verticalXxl,

              // Add Rule Button
              PrimaryButton(
                onPressed: () => context.push(AppRoutes.lockdownRules),
                label: 'Add Rule',
                icon: Icons.add,
              ),
              Spacing.verticalXxl,

              // Quick Actions
              _QuickActions(
                onTrendsTap: () => context.push(AppRoutes.trends),
                onRulesTap: () => context.push(AppRoutes.lockdownRules),
                onAccountabilityTap: () => context.push(AppRoutes.accountability),
              ),
              Spacing.verticalXxl,

              // Weekly Overview
              _WeeklyOverview(weeklyData: weeklyData),
              Spacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.onSettingsTap,
    required this.onAnalyticsTap,
  });

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
              'Wednesday, Oct 22',
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
    required this.hours,
    required this.minutes,
    required this.usageData,
    required this.totalMinutes,
  });

  final int hours;
  final int minutes;
  final List usageData;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
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
                        TextSpan(
                          text: 'h ',
                          style: AppTextStyles.statUnit,
                        ),
                        TextSpan(
                          text: '$minutes',
                          style: AppTextStyles.statLarge,
                        ),
                        TextSpan(
                          text: 'm',
                          style: AppTextStyles.statUnit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Pie Chart
              SizedBox(
                width: 96,
                height: 96,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: usageData.map((data) {
                      return PieChartSectionData(
                        color: data.color,
                        value: data.minutes.toDouble(),
                        radius: 15,
                        showTitle: false,
                      );
                    }).toList(),
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
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Spacing.horizontalSm,
                  Text(
                    '12% less than yesterday',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.trending_up,
                color: AppColors.success,
                size: 16,
              ),
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

  final List usageData;
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
        ...usageData.map((data) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CategoryItem(
                name: data.name,
                minutes: data.minutes,
                color: data.color,
                percentage: data.minutes / totalMinutes,
              ),
            )),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.name,
    required this.minutes,
    required this.color,
    required this.percentage,
  });

  final String name;
  final int minutes;
  final Color color;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

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
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Spacing.horizontalMd,
                  Text(name, style: AppTextStyles.titleMedium),
                ],
              ),
              Text(
                '${hours}h ${mins}m',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          Spacing.verticalSm,
          AppProgressBar(
            value: percentage,
            color: color,
          ),
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
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxValue = weeklyData.reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Week', style: AppTextStyles.titleMedium),
              Text(
                '21h 45m total',
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
              children: List.generate(7, (index) {
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: VerticalBar(
                          value: weeklyData[index],
                          maxValue: maxValue,
                        ),
                      ),
                      Spacing.verticalSm,
                      Text(
                        days[index],
                        style: AppTextStyles.labelSmall,
                      ),
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
