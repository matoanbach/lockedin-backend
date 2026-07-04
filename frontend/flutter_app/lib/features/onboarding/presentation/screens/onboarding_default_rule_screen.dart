import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../preferences/data/preferences_provider.dart';

/// Third onboarding screen - Set default daily limit.
class OnboardingDefaultRuleScreen extends ConsumerStatefulWidget {
  const OnboardingDefaultRuleScreen({super.key});

  @override
  ConsumerState<OnboardingDefaultRuleScreen> createState() =>
      _OnboardingDefaultRuleScreenState();
}

class _OnboardingDefaultRuleScreenState
    extends ConsumerState<OnboardingDefaultRuleScreen> {
  int? _selectedLimit;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(preferencesControllerProvider);

    return preferencesAsync.when(
      data: (preferences) {
        final dailyLimit =
            _selectedLimit ?? preferences.defaultDailyLimitMinutes;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: Spacing.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(
                    title: 'Set Your Default Limit',
                    subtitle:
                        'Choose a daily screen time goal. You can customize this for individual apps later.',
                    onBack: () => context.pop(),
                    label: 'HLR-6',
                  ),
                  Spacing.verticalXxl,
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _TimeDisplayCard(minutes: dailyLimit),
                          Spacing.verticalXxl,
                          _LimitSlider(
                            value: dailyLimit,
                            onChanged: (value) {
                              setState(() => _selectedLimit = value);
                            },
                          ),
                          Spacing.verticalXxl,
                          _PresetOptions(
                            selectedMinutes: dailyLimit,
                            onSelect: (value) {
                              setState(() => _selectedLimit = value);
                            },
                          ),
                          Spacing.verticalXxl,
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
                  PrimaryButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);

                            try {
                              await ref
                                  .read(preferencesControllerProvider.notifier)
                                  .updatePreferences(
                                    hasCompletedOnboarding: true,
                                    defaultDailyLimitMinutes: dailyLimit,
                                  );

                              if (!mounted) {
                                return;
                              }

                              GoRouter.of(this.context).go(AppRoutes.dashboard);
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(describeApiError(error)),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    label: 'Complete Setup',
                    isLoading: _isSaving,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const _AsyncScreenState(
        title: 'Loading your setup',
        message: 'Fetching your saved screen-time preferences.',
      ),
      error: (error, _) => _AsyncScreenState(
        title: 'Could not load setup',
        message: describeApiError(error),
        action: SecondaryButton(
          onPressed: () {
            ref.read(preferencesControllerProvider.notifier).refresh();
          },
          label: 'Retry',
        ),
      ),
    );
  }
}

class _AsyncScreenState extends StatelessWidget {
  const _AsyncScreenState({
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.headlineLarge),
                Spacing.verticalMd,
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                if (action != null) ...[
                  Spacing.verticalXxl,
                  SizedBox(width: 180, child: action),
                ],
              ],
            ),
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
              border: Border.all(color: AppColors.borderPurpleStrong, width: 4),
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
  const _LimitSlider({required this.value, required this.onChanged});

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
            Text('30m', style: AppTextStyles.labelSmall),
            Text('8h', style: AppTextStyles.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _PresetOptions extends StatelessWidget {
  const _PresetOptions({required this.selectedMinutes, required this.onSelect});

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
                        Text(preset.$2, style: AppTextStyles.titleLarge),
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
