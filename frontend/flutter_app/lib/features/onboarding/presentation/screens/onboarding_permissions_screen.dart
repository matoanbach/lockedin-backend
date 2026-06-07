import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../usage/data/usage_sync_provider.dart';

/// Second onboarding screen - Permission requests.
class OnboardingPermissionsScreen extends ConsumerStatefulWidget {
  const OnboardingPermissionsScreen({super.key});

  @override
  ConsumerState<OnboardingPermissionsScreen> createState() =>
      _OnboardingPermissionsScreenState();
}

class _OnboardingPermissionsScreenState
    extends ConsumerState<OnboardingPermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(devicePermissionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionsAsync = ref.watch(devicePermissionsProvider);
    final controller = ref.read(devicePermissionsProvider.notifier);

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
                subtitle:
                    'Grant Usage Access so LockdIn can sync Android app sessions and power your dashboard.',
                onBack: () => context.pop(),
                label: 'HLR-6 • HLR-13-15',
              ),

              Spacing.verticalXxl,

              // Permission Cards
              Expanded(
                child: permissionsAsync.when(
                  data: (permissions) => SingleChildScrollView(
                    child: Column(
                      children: [
                        _PermissionCard(
                          icon: Icons.visibility_outlined,
                          title: 'Usage Access',
                          description:
                              'Required to read Android app sessions and sync them to your local LockdIn backend.',
                          isGranted: permissions.usageAccess,
                          onTap: controller.openUsageAccessSettings,
                        ),
                        Spacing.verticalMd,
                        _PermissionCard(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          description:
                              'Optional for now. Lets LockdIn send limit alerts from this device later.',
                          isGranted: permissions.notifications,
                          onTap: controller.openNotificationSettings,
                        ),
                        Spacing.verticalMd,
                        _PermissionCard(
                          icon: Icons.shield_outlined,
                          title: 'Accessibility Service',
                          description:
                              'Needed for live LockdIn interruptions when a rule limit is reached inside another Android app.',
                          isGranted: permissions.accessibility,
                          onTap: controller.openAccessibilitySettings,
                        ),
                        Spacing.verticalXxl,
                        const InfoCard(
                          message:
                              'Usage sessions sync to your LockdIn backend so analytics stay in sync across the app. Accountability contacts still only receive summary data you choose to share.',
                          icon: '🔒',
                          type: InfoCardType.info,
                        ),
                      ],
                    ),
                  ),
                  loading: () => const _PermissionStateCard(
                    message: 'Checking current Android permission status.',
                  ),
                  error: (error, _) => _PermissionStateCard(
                    message: describeApiError(error),
                    actionLabel: 'Retry',
                    onAction: controller.refresh,
                    isError: true,
                  ),
                ),
              ),

              Spacing.verticalLg,

              // Continue Button
              permissionsAsync.maybeWhen(
                data: (permissions) => PrimaryButton(
                  onPressed: permissions.readyToContinue
                      ? () => context.push(AppRoutes.onboardingDefaultRule)
                      : controller.openUsageAccessSettings,
                  label: permissions.readyToContinue
                      ? 'Continue'
                      : 'Grant Usage Access',
                ),
                orElse: () => const PrimaryButton(
                  onPressed: null,
                  label: 'Checking Permissions',
                  isDisabled: true,
                ),
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

class _PermissionStateCard extends StatelessWidget {
  const _PermissionStateCard({
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
