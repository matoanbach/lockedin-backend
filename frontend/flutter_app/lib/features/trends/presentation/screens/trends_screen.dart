import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../analytics/data/analytics_provider.dart';

/// Trends screen showing usage patterns and insights.
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(trendsAnalyticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Spacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Trends & Insights',
                subtitle: 'Understand your usage patterns',
                onBack: () => context.pop(),
                label: 'HLR-3',
              ),
              Spacing.verticalXxl,
              trendsAsync.when(
                data: (analytics) => _TrendsContent(analytics: analytics),
                loading: () => const _TrendsStateCard(
                  message: 'Loading your latest trend data from the backend.',
                ),
                error: (error, _) => _TrendsStateCard(
                  message: describeApiError(error),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(trendsAnalyticsProvider),
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

class _TrendsContent extends StatelessWidget {
  const _TrendsContent({required this.analytics});

  final TrendsAnalyticsData analytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimeOfDayChart(data: analytics.hourlyUsage),
        Spacing.verticalXxl,
        _PeakUsageCard(peakUsageWindow: analytics.peakUsageWindow),
        Spacing.verticalXxl,
        _WeeklyComparisonChart(data: analytics.weeklyUsage),
        Spacing.verticalXxl,
        _TopAppsSection(apps: analytics.topApps),
        Spacing.verticalXxl,
        InfoCard(
          message: analytics.peakUsageWindow.isEmpty
              ? 'Sync Android usage sessions to unlock trend insights here.'
              : 'Your busiest window is ${analytics.peakUsageWindow}. Consider nudging your evening routine around it.',
          icon: '📈',
          type: analytics.peakUsageWindow.isEmpty
              ? InfoCardType.info
              : InfoCardType.success,
        ),
        Spacing.verticalLg,
      ],
    );
  }
}

class _TimeOfDayChart extends StatelessWidget {
  const _TimeOfDayChart({required this.data});

  final List<HourlyUsage> data;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = data.fold<int>(0, (max, item) => item.minutes > max ? item.minutes : max);
    final maxY = maxMinutes <= 20 ? 20.0 : ((maxMinutes / 20).ceil() * 20).toDouble();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usage by Time of Day', style: AppTextStyles.titleMedium),
          Spacing.verticalLg,
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: AppTextStyles.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length || index % 3 != 0) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[index].hour,
                            style: AppTextStyles.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.minutes.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.primary,
                          strokeWidth: 0,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeakUsageCard extends StatelessWidget {
  const _PeakUsageCard({required this.peakUsageWindow});

  final String peakUsageWindow;

  @override
  Widget build(BuildContext context) {
    final hasInsight = peakUsageWindow.isNotEmpty;

    return GradientCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBox(
            icon: Icons.nightlight_outlined,
            size: 48,
            iconSize: 24,
            color: AppColors.purple400,
          ),
          Spacing.horizontalLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasInsight ? 'Peak Usage Window' : 'Trend Insight Pending',
                  style: AppTextStyles.titleMedium,
                ),
                Spacing.verticalXs,
                Text(
                  hasInsight
                      ? 'Your busiest usage window lately is $peakUsageWindow. That is the best slot to place a wind-down habit or stricter rule.'
                      : 'Once Android usage events start syncing, this card will call out the busiest time window in your day.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyComparisonChart extends StatelessWidget {
  const _WeeklyComparisonChart({required this.data});

  final List<DailyUsage> data;

  @override
  Widget build(BuildContext context) {
    final totalHours = data.fold<double>(0, (sum, item) => sum + item.hours);
    final maxY = data.fold<double>(0, (max, item) => item.hours > max ? item.hours : max);

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Week', style: AppTextStyles.titleMedium),
              Text(
                '${totalHours.toStringAsFixed(1)}h total',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          Spacing.verticalLg,
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY <= 2 ? 1 : maxY / 4),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}h',
                        style: AppTextStyles.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[index].day,
                            style: AppTextStyles.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.hours,
                        color: AppColors.primary,
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                maxY: maxY == 0 ? 1 : maxY + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopAppsSection extends StatelessWidget {
  const _TopAppsSection({required this.apps});

  final List<TopAppUsage> apps;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = apps.fold<int>(0, (max, item) => item.minutes > max ? item.minutes : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Apps This Week',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Spacing.verticalMd,
        if (apps.isEmpty)
          const AppCard(
            child: Text('No app usage has been aggregated yet.'),
          )
        else
          ...apps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.apps_rounded,
                          color: _topAppColor(entry.key),
                          size: 20,
                        ),
                        Spacing.horizontalMd,
                        Expanded(
                          child: Text(
                            entry.value.appName,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        Text(
                          entry.value.formattedTime,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    Spacing.verticalSm,
                    AppProgressBar(
                      value: maxMinutes == 0 ? 0 : entry.value.minutes / maxMinutes,
                      color: _topAppColor(entry.key),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrendsStateCard extends StatelessWidget {
  const _TrendsStateCard({
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

Color _topAppColor(int index) {
  const palette = [
    AppColors.chart1,
    AppColors.chart2,
    AppColors.info,
    AppColors.warning,
    AppColors.success,
  ];

  return palette[index % palette.length];
}
