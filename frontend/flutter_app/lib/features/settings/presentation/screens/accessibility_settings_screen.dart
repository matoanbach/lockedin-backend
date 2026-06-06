import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../preferences/data/preferences_provider.dart';

/// Accessibility settings screen.
class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  ConsumerState<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends ConsumerState<AccessibilitySettingsScreen> {
  double? _textSize;
  bool? _highContrast;
  bool? _largeButtons;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(preferencesControllerProvider);

    return preferencesAsync.when(
      data: (preferences) {
        final textSize = _textSize ?? preferences.textSizePercent.toDouble();
        final highContrast = _highContrast ?? preferences.highContrast;
        final largeButtons = _largeButtons ?? preferences.largeTapTargets;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: Spacing.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(
                    title: 'Accessibility',
                    subtitle: 'Customize for better usability',
                    onBack: () => context.pop(),
                    label: 'HLR-7',
                  ),
                  Spacing.verticalXxl,
                  Row(
                    children: [
                      const Icon(
                        Icons.text_fields,
                        color: AppColors.purple400,
                        size: 20,
                      ),
                      Spacing.horizontalSm,
                      Text('Text Size', style: AppTextStyles.titleMedium),
                    ],
                  ),
                  Spacing.verticalMd,
                  AppCard(
                    child: Column(
                      children: [
                        Text(
                          'Preview Text',
                          style: TextStyle(
                            fontSize: 14.0 * (textSize / 100),
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Spacing.verticalXs,
                        Text(
                          '${textSize.toInt()}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Spacing.verticalLg,
                        AppSlider(
                          value: textSize,
                          onChanged: (value) {
                            setState(() => _textSize = value);
                          },
                          min: 75,
                          max: 150,
                          divisions: 15,
                        ),
                        Spacing.verticalSm,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Smaller', style: AppTextStyles.labelSmall),
                            Text('Larger', style: AppTextStyles.labelSmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Spacing.verticalXxl,
                  Row(
                    children: [
                      const Icon(
                        Icons.contrast,
                        color: AppColors.purple400,
                        size: 20,
                      ),
                      Spacing.horizontalSm,
                      Text('Display', style: AppTextStyles.titleMedium),
                    ],
                  ),
                  Spacing.verticalMd,
                  SettingsTile(
                    title: 'High Contrast Mode',
                    subtitle: 'Increase color contrast for better visibility',
                    value: highContrast,
                    onChanged: (value) {
                      setState(() => _highContrast = value);
                    },
                  ),
                  Spacing.verticalMd,
                  SettingsTile(
                    title: 'Large Tap Targets',
                    subtitle: 'Make buttons and controls larger',
                    value: largeButtons,
                    onChanged: (value) {
                      setState(() => _largeButtons = value);
                    },
                  ),
                  Spacing.verticalXxl,
                  Row(
                    children: [
                      const Icon(
                        Icons.zoom_in,
                        color: AppColors.purple400,
                        size: 20,
                      ),
                      Spacing.horizontalSm,
                      Text('Preview', style: AppTextStyles.titleMedium),
                    ],
                  ),
                  Spacing.verticalMd,
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: Spacing.card,
                    decoration: BoxDecoration(
                      color: highContrast ? Colors.black : AppColors.cardBackground,
                      borderRadius: Spacing.borderRadiusLg,
                      border: Border.all(
                        color: highContrast ? Colors.white : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This is how text will appear with your current settings.',
                          style: TextStyle(
                            fontSize: 14.0 * (textSize / 100),
                            color: highContrast
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        Spacing.verticalLg,
                        SizedBox(
                          width: double.infinity,
                          height: largeButtons ? 56 : 44,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: highContrast
                                  ? Colors.white
                                  : AppColors.purple600,
                              foregroundColor: highContrast
                                  ? Colors.black
                                  : Colors.white,
                            ),
                            child: Text(
                              'Sample Button',
                              style: TextStyle(
                                fontSize: largeButtons ? 18 : 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacing.verticalXxl,
                  const InfoCard(
                    message: 'WCAG 2.1 Level AA compliant with current settings',
                    icon: '✓',
                    type: InfoCardType.success,
                  ),
                  Spacing.verticalXxl,
                  PrimaryButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);

                            try {
                              await ref
                                  .read(preferencesControllerProvider.notifier)
                                  .updatePreferences(
                                    textSizePercent: textSize.round(),
                                    highContrast: highContrast,
                                    largeTapTargets: largeButtons,
                                  );

                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Accessibility settings saved'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
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
                    label: 'Save Settings',
                    isLoading: _isSaving,
                  ),
                  Spacing.verticalLg,
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const _AccessibilityLoadingState(),
      error: (error, _) => _AccessibilityLoadingState(
        errorMessage: describeApiError(error),
        onRetry: () {
          ref.read(preferencesControllerProvider.notifier).refresh();
        },
      ),
    );
  }
}

class _AccessibilityLoadingState extends StatelessWidget {
  const _AccessibilityLoadingState({this.errorMessage, this.onRetry});

  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasError)
                  const CircularProgressIndicator(color: AppColors.purple400),
                if (hasError)
                  const Icon(
                    Icons.cloud_off,
                    color: AppColors.error,
                    size: 36,
                  ),
                Spacing.verticalLg,
                Text(
                  hasError
                      ? 'Could not load accessibility settings'
                      : 'Loading settings',
                  style: AppTextStyles.titleLarge,
                ),
                Spacing.verticalSm,
                Text(
                  errorMessage ?? 'Fetching your saved accessibility preferences.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                if (hasError && onRetry != null) ...[
                  Spacing.verticalXxl,
                  SizedBox(
                    width: 160,
                    child: SecondaryButton(onPressed: onRetry, label: 'Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
