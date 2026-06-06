import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';

/// Provider for star rating.
final ratingProvider = NotifierProvider<RatingNotifier, int>(RatingNotifier.new);
final feedbackProvider = NotifierProvider<FeedbackNotifier, String>(FeedbackNotifier.new);

class RatingNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void set(int value) => state = value;
}

class FeedbackNotifier extends Notifier<String> {
  @override
  String build() => '';
  
  void set(String value) => state = value;
}

/// Analytics summary / weekly review screen.
class AnalyticsSummaryScreen extends ConsumerWidget {
  const AnalyticsSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(ratingProvider);

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
                title: 'Weekly Summary',
                subtitle: 'Your progress this week',
                onBack: () => context.pop(),
                label: 'HLR-8-12',
              ),
              Spacing.verticalXxl,

              // Main Achievement Card
              _MainAchievementCard(),
              Spacing.verticalXxl,

              // Stats Grid
              _StatsGrid(),
              Spacing.verticalXxl,

              // Achievements
              _AchievementsSection(),
              Spacing.verticalXxl,

              // Rating Section
              _RatingSection(
                rating: rating,
                onRatingChanged: (value) {
                  ref.read(ratingProvider.notifier).set(value);
                },
                onSubmit: () {
                  if (rating == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a rating'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your feedback!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  ref.read(ratingProvider.notifier).set(0);
                  ref.read(feedbackProvider.notifier).set('');
                },
              ),
              Spacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }
}

class _MainAchievementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
        border: Border.all(
          color: AppColors.borderPurpleStrong,
        ),
      ),
      child: Column(
        children: [
          // Trophy Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.purple400,
                width: 4,
              ),
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

          // Percentage
          Text(
            '26%',
            style: AppTextStyles.displayLarge,
          ),
          Spacing.verticalSm,
          Text(
            'Screen time reduction',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.purple200,
            ),
          ),
          Spacing.verticalMd,

          // Progress indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.trending_down,
                color: AppColors.success,
                size: 20,
              ),
              Spacing.horizontalSm,
              Text(
                'Great progress!',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.success,
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
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _StatCard(
          value: '18h',
          label: 'Total this week',
          change: '-5.8h from last week',
          isPositive: true,
        ),
        _StatCard(
          value: '2.6h',
          label: 'Daily average',
          change: '-49min per day',
          isPositive: true,
        ),
        _StatCard(
          value: '4/7',
          label: 'Goals met',
          change: '57% success rate',
          isPositive: null,
        ),
        _StatCard(
          value: '12',
          label: 'Longest streak',
          change: 'days',
          isPositive: null,
        ),
      ],
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
            style: AppTextStyles.labelSmall.copyWith(
              color: changeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements Unlocked',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Spacing.verticalMd,
        _AchievementCard(
          icon: Icons.star,
          title: 'Week Warrior',
          description: 'Met goals 4 days this week',
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
          title: 'Focus Master',
          description: 'Under 3h for 3 consecutive days',
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
        gradient: LinearGradient(
          colors: gradientColors,
        ),
        borderRadius: Spacing.borderRadiusLg,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          IconBox(
            icon: icon,
            size: 48,
            iconSize: 24,
            color: iconColor,
          ),
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

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.rating,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate Your Experience', style: AppTextStyles.titleMedium),
          Spacing.verticalSm,
          Text(
            'How would you rate LockdIn this week?',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          Spacing.verticalLg,

          // Star Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starIndex <= rating ? Icons.star : Icons.star_border,
                    size: 32,
                    color: starIndex <= rating
                        ? AppColors.warning
                        : AppColors.textMuted,
                  ),
                ),
              );
            }),
          ),
          Spacing.verticalLg,

          // Feedback TextField
          TextField(
            maxLines: 3,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Share your thoughts (optional)',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Spacing.verticalLg,

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubmit,
              child: const Text('Submit Feedback'),
            ),
          ),
        ],
      ),
    );
  }
}
