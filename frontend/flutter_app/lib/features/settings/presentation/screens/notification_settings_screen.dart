import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../preferences/data/preferences_provider.dart';

/// Notification settings screen.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationTone? _selectedTone;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(preferencesControllerProvider);

    return preferencesAsync.when(
      data: (preferences) {
        final selectedTone = _selectedTone ?? preferences.notificationTone;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: Spacing.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(
                    title: 'Notifications',
                    subtitle: 'Customize your notification style',
                    onBack: () => context.pop(),
                    label: 'HLR-4',
                  ),
                  Spacing.verticalXxl,
                  Row(
                    children: [
                      const Icon(
                        Icons.volume_up_outlined,
                        color: AppColors.purple400,
                        size: 20,
                      ),
                      Spacing.horizontalSm,
                      Text('Notification Tone', style: AppTextStyles.titleMedium),
                    ],
                  ),
                  Spacing.verticalMd,
                  ...NotificationTone.values.map(
                    (tone) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ToneOptionCard(
                        tone: tone,
                        isSelected: selectedTone == tone,
                        onTap: () {
                          setState(() => _selectedTone = tone);
                        },
                      ),
                    ),
                  ),
                  Spacing.verticalXxl,
                  Text(
                    'Other Settings',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Spacing.verticalMd,
                  _SettingsNavItem(
                    icon: Icons.settings_outlined,
                    label: 'Accessibility',
                    onTap: () => context.push(AppRoutes.accessibilitySettings),
                  ),
                  Spacing.verticalMd,
                  _SettingsNavItem(
                    icon: Icons.settings_outlined,
                    label: 'Privacy & Data',
                    onTap: () => context.push(AppRoutes.privacyPolicy),
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
                                  .updatePreferences(notificationTone: selectedTone);

                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Notification tone updated to ${selectedTone.displayName}',
                                  ),
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
                    label: 'Save Changes',
                    isLoading: _isSaving,
                  ),
                  Spacing.verticalLg,
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const _NotificationLoadingState(),
      error: (error, _) => _NotificationLoadingState(
        errorMessage: describeApiError(error),
        onRetry: () {
          ref.read(preferencesControllerProvider.notifier).refresh();
        },
      ),
    );
  }
}

class _NotificationLoadingState extends StatelessWidget {
  const _NotificationLoadingState({this.errorMessage, this.onRetry});

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
                      ? 'Could not load notification settings'
                      : 'Loading settings',
                  style: AppTextStyles.titleLarge,
                ),
                Spacing.verticalSm,
                Text(
                  errorMessage ?? 'Fetching your saved notification tone.',
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

class _ToneOptionCard extends StatelessWidget {
  const _ToneOptionCard({
    required this.tone,
    required this.isSelected,
    required this.onTap,
  });

  final NotificationTone tone;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: Spacing.card,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.cardBackground,
          borderRadius: Spacing.borderRadiusLg,
          border: Border.all(
            color: isSelected ? AppColors.borderPurpleStrong : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            Spacing.horizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tone.displayName, style: AppTextStyles.titleMedium),
                  Spacing.verticalXs,
                  Text(
                    tone.description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Spacing.verticalMd,
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: Spacing.borderRadiusMd,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      tone.example,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
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
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  const _SettingsNavItem({
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
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.purple400, size: 20),
              Spacing.horizontalMd,
              Text(label, style: AppTextStyles.bodyMedium),
            ],
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
