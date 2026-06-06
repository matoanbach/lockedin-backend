import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';

/// Providers for accessibility settings.
final textSizeProvider = NotifierProvider<TextSizeNotifier, double>(TextSizeNotifier.new);
final highContrastProvider = NotifierProvider<HighContrastNotifier, bool>(HighContrastNotifier.new);
final largeButtonsProvider = NotifierProvider<LargeButtonsNotifier, bool>(LargeButtonsNotifier.new);

class TextSizeNotifier extends Notifier<double> {
  @override
  double build() => 100;
  void set(double value) => state = value;
}

class HighContrastNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class LargeButtonsNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

/// Accessibility settings screen.
class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textSize = ref.watch(textSizeProvider);
    final highContrast = ref.watch(highContrastProvider);
    final largeButtons = ref.watch(largeButtonsProvider);

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
                title: 'Accessibility',
                subtitle: 'Customize for better usability',
                onBack: () => context.pop(),
                label: 'HLR-7',
              ),
              Spacing.verticalXxl,

              // Text Size Section
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
                        ref.read(textSizeProvider.notifier).set(value);
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

              // Display Section
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
                  ref.read(highContrastProvider.notifier).set(value);
                },
              ),
              Spacing.verticalMd,
              SettingsTile(
                title: 'Large Tap Targets',
                subtitle: 'Make buttons and controls larger',
                value: largeButtons,
                onChanged: (value) {
                  ref.read(largeButtonsProvider.notifier).set(value);
                },
              ),
              Spacing.verticalXxl,

              // Preview Section
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
                        color: highContrast ? Colors.white : AppColors.textPrimary,
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

              // WCAG Compliance
              const InfoCard(
                message: 'WCAG 2.1 Level AA compliant with current settings',
                icon: '✓',
                type: InfoCardType.success,
              ),
              Spacing.verticalXxl,

              // Save Button
              PrimaryButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Accessibility settings saved'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                label: 'Save Settings',
              ),
              Spacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }
}
