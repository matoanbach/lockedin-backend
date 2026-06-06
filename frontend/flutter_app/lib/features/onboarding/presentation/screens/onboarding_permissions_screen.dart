import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/providers/onboarding_provider.dart';

/// Second onboarding screen - Permission requests.
class OnboardingPermissionsScreen extends ConsumerWidget {
  const OnboardingPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(onboardingPermissionsProvider);
    final notifier = ref.read(onboardingPermissionsProvider.notifier);

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
                title: 'Grant Permissions',
                subtitle: 'LockdIn needs these permissions to track your app usage and help you stay focused.',
                onBack: () => context.pop(),
                label: 'HLR-6 • HLR-13-15',
              ),
              
              Spacing.verticalXxl,
              
              // Permission Cards
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _PermissionCard(
                        icon: Icons.visibility_outlined,
                        title: 'Usage Access',
                        description: 'Required to monitor which apps you use and for how long',
                        isGranted: permissions.usageAccess,
                        onTap: notifier.toggleUsageAccess,
                      ),
                      Spacing.verticalMd,
                      _PermissionCard(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        description: 'Get alerts when you\'re approaching or exceeding limits',
                        isGranted: permissions.notifications,
                        onTap: notifier.toggleNotifications,
                      ),
                      Spacing.verticalMd,
                      _PermissionCard(
                        icon: Icons.shield_outlined,
                        title: 'Accessibility Service',
                        description: 'Enables app blocking when you exceed your limits',
                        isGranted: permissions.accessibility,
                        onTap: notifier.toggleAccessibility,
                      ),
                      Spacing.verticalXxl,
                      
                      // Privacy Note
                      const InfoCard(
                        message: 'Your data stays on your device. We never collect or share your personal information.',
                        icon: '🔒',
                        type: InfoCardType.info,
                      ),
                    ],
                  ),
                ),
              ),
              
              Spacing.verticalLg,
              
              // Continue Button
              PrimaryButton(
                onPressed: permissions.allGranted
                    ? () => context.push(AppRoutes.onboardingDefaultRule)
                    : null,
                label: permissions.allGranted ? 'Continue' : 'Grant All Permissions',
                isDisabled: !permissions.allGranted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: Spacing.card,
        decoration: BoxDecoration(
          color: isGranted
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.cardBackground,
          borderRadius: Spacing.borderRadiusLg,
          border: Border.all(
            color: isGranted ? AppColors.borderPurpleStrong : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBox(
              icon: icon,
              size: 48,
              iconSize: 24,
              color: isGranted ? AppColors.purple400 : AppColors.textTertiary,
            ),
            Spacing.horizontalLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: AppTextStyles.titleMedium),
                      if (isGranted)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.purple400,
                          size: 20,
                        ),
                    ],
                  ),
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
      ),
    );
  }
}
