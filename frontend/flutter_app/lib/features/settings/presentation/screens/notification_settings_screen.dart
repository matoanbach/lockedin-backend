import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../shared/models/models.dart';

/// Provider for notification tone setting.
final notificationToneProvider =
    NotifierProvider<NotificationToneNotifier, NotificationTone>(
  NotificationToneNotifier.new,
);

class NotificationToneNotifier extends Notifier<NotificationTone> {
  @override
  NotificationTone build() => NotificationTone.professional;
  void set(NotificationTone value) => state = value;
}

/// Notification settings screen.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTone = ref.watch(notificationToneProvider);

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
                title: 'Notifications',
                subtitle: 'Customize your notification style',
                onBack: () => context.pop(),
                label: 'HLR-4',
              ),
              Spacing.verticalXxl,

              // Notification Tone Section
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

              // Tone Options
              ...NotificationTone.values.map((tone) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ToneOptionCard(
                      tone: tone,
                      isSelected: selectedTone == tone,
                      onTap: () {
                        ref.read(notificationToneProvider.notifier).set(tone);
                      },
                    ),
                  )),
              Spacing.verticalXxl,

              // Other Settings
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

              // Save Button
              PrimaryButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Notification tone updated to ${selectedTone.displayName}',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                label: 'Save Changes',
              ),
              Spacing.verticalLg,
            ],
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
            Radio<NotificationTone>(
              value: tone,
              groupValue: isSelected ? tone : null,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primary,
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
