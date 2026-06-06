import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../shared/models/models.dart';

/// Trends screen showing usage patterns and insights.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  static const hourlyData = [
    HourlyUsage(hour: '6am', minutes: 5),
    HourlyUsage(hour: '9am', minutes: 15),
    HourlyUsage(hour: '12pm', minutes: 35),
    HourlyUsage(hour: '3pm', minutes: 25),
    HourlyUsage(hour: '6pm', minutes: 45),
    HourlyUsage(hour: '9pm', minutes: 65),
    HourlyUsage(hour: '12am', minutes: 35),
  ];

  static const weeklyData = [
    DailyUsage(day: 'Mon', hours: 3.2),
    DailyUsage(day: 'Tue', hours: 4.5),
    DailyUsage(day: 'Wed', hours: 2.8),
    DailyUsage(day: 'Thu', hours: 5.1),
    DailyUsage(day: 'Fri', hours: 4.2),
    DailyUsage(day: 'Sat', hours: 6.3),
    DailyUsage(day: 'Sun', hours: 5.8),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Spacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ScreenHeader(
                title: 'Trends & Insights',
                subtitle: 'Understand your usage patterns',
                onBack: () => context.pop(),
                label: 'HLR-3',
              ),
              Spacing.verticalXxl,

              // Time of Day Chart
              _TimeOfDayChart(data: hourlyData),
              Spacing.verticalXxl,

              // Peak Usage Insight
              _PeakUsageCard(),
              Spacing.verticalXxl,

              // Weekly Comparison
              _WeeklyComparisonChart(data: weeklyData),
              Spacing.verticalXxl,

              // Location Insights
              _LocationInsights(),
              Spacing.verticalXxl,

              // Recommendation
              const InfoCard(
                message: 'Great progress! You\'ve reduced screen time by 26% this week. Keep it up!',
                icon: '📈',
                type: InfoCardType.success,
              ),
              Spacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeOfDayChart extends StatelessWidget {
  const _TimeOfDayChart({required this.data});

  final List<HourlyUsage> data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usage by Time of Day', style: AppTextStyles.titleMedium),
          Spacing.verticalLg,
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
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
                        if (value.toInt() >= 0 && value.toInt() < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[value.toInt()].hour,
                              style: AppTextStyles.labelSmall,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
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
                    spots: data.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.minutes.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
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
                maxY: 80,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeakUsageCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GradientCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(
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
                Text('Peak Usage: Evenings', style: AppTextStyles.titleMedium),
                Spacing.verticalXs,
                Text(
                  'You scroll more at night, especially between 9 PM - 11 PM. Try setting a wind-down routine.',
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
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Week', style: AppTextStyles.titleMedium),
              Row(
                children: [
                  const Icon(
                    Icons.trending_down,
                    color: AppColors.success,
                    size: 16,
                  ),
                  Spacing.horizontalXs,
                  Text(
                    '12% less',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
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
                  horizontalInterval: 2,
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
                        if (value.toInt() >= 0 && value.toInt() < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[value.toInt()].day,
                              style: AppTextStyles.labelSmall,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
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
                barGroups: data.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.hours,
                        color: AppColors.primary,
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                maxY: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationInsights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Insights',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Spacing.verticalMd,
        _LocationCard(
          name: 'Home',
          averageHours: 3.2,
          percentage: 0.65,
        ),
        Spacing.verticalMd,
        _LocationCard(
          name: 'Work/School',
          averageHours: 1.8,
          percentage: 0.35,
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.name,
    required this.averageHours,
    required this.percentage,
  });

  final String name;
  final double averageHours;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.purple400,
                size: 20,
              ),
              Spacing.horizontalMd,
              Text(name, style: AppTextStyles.titleMedium),
            ],
          ),
          Spacing.verticalSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Average usage',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                '${averageHours}h/day',
                style: AppTextStyles.titleSmall,
              ),
            ],
          ),
          Spacing.verticalSm,
          AppProgressBar(
            value: percentage,
            height: 8,
          ),
        ],
      ),
    );
  }
}
