import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/providers/onboarding_provider.dart';

/// Third onboarding screen - Set default daily limit.
class OnboardingDefaultRuleScreen extends ConsumerWidget {
  const OnboardingDefaultRuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLimit = ref.watch(defaultDailyLimitProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ScreenHeader(
                title: 'Set Your Default Limit',
                subtitle: 'Choose a daily screen time goal. You can customize this for individual apps later.',
                onBack: () => context.pop(),
                label: 'HLR-6',
              ),
              
              Spacing.verticalXxl,
              
              // Time Display Card
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _TimeDisplayCard(minutes: dailyLimit),
                      Spacing.verticalXxl,
                      
                      // Slider Section
                      _LimitSlider(
                        value: dailyLimit,
                        onChanged: (value) {
                          ref.read(defaultDailyLimitProvider.notifier).set(value);
                        },
                      ),
                      Spacing.verticalXxl,
                      
                      // Preset Options
                      _PresetOptions(
                        selectedMinutes: dailyLimit,
                        onSelect: (value) {
                          ref.read(defaultDailyLimitProvider.notifier).set(value);
                        },
                      ),
                      Spacing.verticalXxl,
                      
                      // Info Card
                      AppCard(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.smartphone,
                              color: AppColors.purple400,
                              size: 20,
                            ),
                            Spacing.horizontalMd,
                            Expanded(
                              child: Text(
                                'This is your total daily limit across all apps. Individual app limits can be set from the dashboard.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Spacing.verticalLg,
              
              // Complete Button
              PrimaryButton(
                onPressed: () {
                  ref.read(hasCompletedOnboardingProvider.notifier).complete();
                  context.go(AppRoutes.dashboard);
                },
                label: 'Complete Setup',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeDisplayCard extends StatelessWidget {
  const _TimeDisplayCard({required this.minutes});

  final int minutes;

  String get formattedTime {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    }
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Clock Icon
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.borderPurpleStrong,
                width: 4,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.access_time,
                size: 64,
                color: AppColors.purple400,
              ),
            ),
          ),
          Spacing.verticalXxl,
          
          // Time Display
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              formattedTime,
              key: ValueKey(minutes),
              style: AppTextStyles.displayLarge,
            ),
          ),
          Spacing.verticalSm,
          Text(
            'per day',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitSlider extends StatelessWidget {
  const _LimitSlider({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Less restrictive',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              'More restrictive',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        Spacing.verticalMd,
        AppSlider(
          value: value.toDouble(),
          onChanged: (v) => onChanged(v.round()),
          min: 30,
          max: 480,
          divisions: 30,
        ),
        Spacing.verticalSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '30m',
              style: AppTextStyles.labelSmall,
            ),
            Text(
              '8h',
              style: AppTextStyles.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetOptions extends StatelessWidget {
  const _PresetOptions({
    required this.selectedMinutes,
    required this.onSelect,
  });

  final int selectedMinutes;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final presets = [
      (120, '2h', 'Focused'),
      (180, '3h', 'Balanced'),
      (240, '4h', 'Relaxed'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick presets:',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        Spacing.verticalMd,
        Row(
          children: presets.map((preset) {
            final isSelected = selectedMinutes == preset.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: preset != presets.last ? 12 : 0,
                ),
                child: GestureDetector(
                  onTap: () => onSelect(preset.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.cardBackground,
                      borderRadius: Spacing.borderRadiusMd,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.borderPurpleStrong
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          preset.$2,
                          style: AppTextStyles.titleLarge,
                        ),
                        Spacing.verticalXs,
                        Text(
                          preset.$3,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isSelected
                                ? AppColors.purple300
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
