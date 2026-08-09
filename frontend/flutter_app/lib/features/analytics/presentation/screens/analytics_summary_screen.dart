import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/analytics_provider.dart';

/// Analytics summary / weekly review screen.
class AnalyticsSummaryScreen extends ConsumerWidget {
  const AnalyticsSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(weeklySummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Spacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Weekly Summary',
                subtitle: 'Your progress this week',
                onBack: () => context.pop(),
              ),
              Spacing.verticalXxl,
              summaryAsync.when(
                data: (summary) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MainAchievementCard(summary: summary),
                    Spacing.verticalXxl,
                    _StatsGrid(summary: summary),
                    Spacing.verticalXxl,
                    _AchievementsSection(summary: summary),
                    Spacing.verticalLg,
                  ],
                ),
                loading: () => const _SummaryStateCard(
                  message: 'Loading this week\'s backend summary.',
                ),
                error: (error, _) => _SummaryStateCard(
                  message: describeApiError(error),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(weeklySummaryProvider),
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

class _MainAchievementCard extends StatelessWidget {
  const _MainAchievementCard({required this.summary});

  final WeeklySummaryData summary;

  @override
  Widget build(BuildContext context) {
    final metricColor = summary.hasRegression
        ? AppColors.error
        : summary.hasImproved
        ? AppColors.success
        : AppColors.purple200;
    final title = summary.hasRegression
        ? 'Screen time increase'
        : 'Screen time reduction';
    final caption = summary.hasRegression
        ? 'A heavier week than last week'
        : summary.hasImproved
        ? 'Great progress!'
        : 'Holding steady week over week';
    final trendIcon = summary.hasRegression
        ? Icons.trending_up
        : summary.hasImproved
        ? Icons.trending_down
        : Icons.horizontal_rule;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple600.withValues(alpha: 0.3),
            AppColors.purple400.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: Spacing.borderRadiusXxl,
        border: Border.all(color: AppColors.borderPurpleStrong),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.purple400, width: 4),
            ),
            child: const Center(
              child: Icon(
                Icons.emoji_events,
                size: 40,
                color: AppColors.purple300,
              ),
            ),
          ),
          Spacing.verticalLg,
          Text(
            '${summary.screenTimeReductionPercent.abs()}%',
            style: AppTextStyles.displayLarge,
          ),
          Spacing.verticalSm,
          Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.purple200,
            ),
          ),
          Spacing.verticalMd,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(trendIcon, color: metricColor, size: 20),
              Spacing.horizontalSm,
              Flexible(
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium.copyWith(color: metricColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary});

  final WeeklySummaryData summary;

  @override
  Widget build(BuildContext context) {
    final totalWeekChange = summary.screenTimeReductionPercent == 0
        ? 'Same as last week'
        : summary.hasImproved
        ? '${summary.screenTimeReductionPercent}% less than last week'
        : '${summary.screenTimeReductionPercent.abs()}% more than last week';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return GridView.count(
          crossAxisCount: isNarrow ? 1 : 2,
          childAspectRatio: isNarrow ? 2.2 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              value: '${_formatHours(summary.totalWeekHours)}h',
              label: 'Total this week',
              change: totalWeekChange,
              isPositive: summary.hasImproved
                  ? true
                  : summary.hasRegression
                  ? false
                  : null,
            ),
            _StatCard(
              value: '${_formatHours(summary.dailyAverageHours)}h',
              label: 'Daily average',
              change: '${_formatHours(summary.dailyAverageHours)}h per day',
              isPositive: null,
            ),
            _StatCard(
              value: '${summary.goalsMetDays}/7',
              label: 'Goals met',
              change: '${summary.goalSuccessPercent}% success rate',
              isPositive: null,
            ),
            _StatCard(
              value: '${summary.longestStreakDays}',
              label: 'Longest streak',
              change: _dayUnit(summary.longestStreakDays),
              isPositive: null,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.change,
    this.isPositive,
  });

  final String value;
  final String label;
  final String change;
  final bool? isPositive;

  @override
  Widget build(BuildContext context) {
    final changeColor = isPositive == null
        ? AppColors.purple400
        : isPositive!
        ? AppColors.success
        : AppColors.error;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: AppTextStyles.statMedium),
          Spacing.verticalXs,
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          Spacing.verticalSm,
          Text(
            change,
            style: AppTextStyles.labelSmall.copyWith(color: changeColor),
          ),
        ],
      ),
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({required this.summary});

  final WeeklySummaryData summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Highlights',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Spacing.verticalXs,
        Text(
          'Your goal progress and best streak, updated weekly.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        Spacing.verticalMd,
        _AchievementCard(
          icon: Icons.star,
          title: 'Goal Progress',
          description:
              'Met goals ${summary.goalsMetDays} ${_dayUnit(summary.goalsMetDays)} this week',
          gradientColors: [
            AppColors.warning.withValues(alpha: 0.1),
            Colors.orange.withValues(alpha: 0.1),
          ],
          borderColor: AppColors.warning.withValues(alpha: 0.3),
          iconColor: AppColors.warning,
        ),
        Spacing.verticalMd,
        _AchievementCard(
          icon: Icons.track_changes,
          title: 'Best Streak',
          description: summary.longestStreakDays == 0
              ? 'Your streak will appear once usage syncs in.'
              : 'Best streak so far: ${summary.longestStreakDays} ${_dayUnit(summary.longestStreakDays)} under goal',
          gradientColors: [
            AppColors.info.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.1),
          ],
          borderColor: AppColors.info.withValues(alpha: 0.3),
          iconColor: AppColors.info,
        ),
      ],
    );
  }
}

String _dayUnit(int days) => days == 1 ? 'day' : 'days';

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
    required this.borderColor,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: Spacing.borderRadiusLg,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          IconBox(icon: icon, size: 48, iconSize: 24, color: iconColor),
          Spacing.horizontalLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                Spacing.verticalXs,
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
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

class _SummaryStateCard extends StatelessWidget {
  const _SummaryStateCard({
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

String _formatHours(double hours) {
  final rounded = hours.toStringAsFixed(1);
  return rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
}
