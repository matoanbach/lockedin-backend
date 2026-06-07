import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../usage/data/usage_sync_provider.dart';

class DevicePermissionsScreen extends ConsumerStatefulWidget {
  const DevicePermissionsScreen({super.key});

  @override
  ConsumerState<DevicePermissionsScreen> createState() =>
      _DevicePermissionsScreenState();
}

class _DevicePermissionsScreenState
    extends ConsumerState<DevicePermissionsScreen>
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
        child: SingleChildScrollView(
          padding: Spacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Device Permissions',
                subtitle:
                    'Manage the Android access LockdIn needs for tracking, alerts, and live interventions.',
                onBack: () => context.pop(),
                label: 'HLR-4 • HLR-13-15',
              ),
              Spacing.verticalXxl,
              permissionsAsync.when(
                data: (permissions) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PermissionTile(
                      icon: Icons.visibility_outlined,
                      title: 'Usage Access',
                      description:
                          'Required so LockdIn can read Android app sessions and sync them into analytics.',
                      isGranted: permissions.usageAccess,
                      onTap: controller.openUsageAccessSettings,
                    ),
                    Spacing.verticalMd,
                    _PermissionTile(
                      icon: Icons.shield_outlined,
                      title: 'Accessibility Service',
                      description:
                          'Required for live LockdIn interruptions when you hit a saved app limit.',
                      isGranted: permissions.accessibility,
                      onTap: controller.openAccessibilitySettings,
                    ),
                    Spacing.verticalMd,
                    _PermissionTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      description:
                          'Optional, but recommended, so LockdIn can surface local warnings before you cross a limit.',
                      isGranted: permissions.notifications,
                      onTap: controller.openNotificationSettings,
                    ),
                    Spacing.verticalLg,
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            onPressed: controller.refresh,
                            label: 'Refresh Status',
                            icon: Icons.refresh,
                          ),
                        ),
                      ],
                    ),
                    Spacing.verticalXxl,
                    const InfoCard(
                      message:
                          'Tap any permission row to open the matching Android settings page. When you return to LockdIn, this screen refreshes automatically.',
                      icon: 'i',
                      type: InfoCardType.info,
                    ),
                  ],
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
              Spacing.verticalXxl,
              Text(
                'App Settings',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Spacing.verticalMd,
              _SettingsNavItem(
                icon: Icons.volume_up_outlined,
                label: 'Notification Tone',
                onTap: () => context.push(AppRoutes.notificationSettings),
              ),
              Spacing.verticalMd,
              _SettingsNavItem(
                icon: Icons.text_fields_outlined,
                label: 'Display & Accessibility',
                onTap: () =>
                    context.push(AppRoutes.displayAccessibilitySettings),
              ),
              Spacing.verticalMd,
              _SettingsNavItem(
                icon: Icons.lock_outline,
                label: 'Privacy & Data',
                onTap: () => context.push(AppRoutes.privacyPolicy),
              ),
              Spacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
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
    final accent = isGranted ? AppColors.purple400 : AppColors.textMuted;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: icon, size: 48, iconSize: 24, color: accent),
          Spacing.horizontalLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppTextStyles.titleMedium),
                    ),
                    _PermissionStatusChip(isGranted: isGranted),
                  ],
                ),
                Spacing.verticalXs,
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Spacing.verticalMd,
                Text(
                  isGranted
                      ? 'Tap to review this Android setting.'
                      : 'Tap to open Android settings and enable it.',
                  style: AppTextStyles.labelSmall.copyWith(color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionStatusChip extends StatelessWidget {
  const _PermissionStatusChip({required this.isGranted});

  final bool isGranted;

  @override
  Widget build(BuildContext context) {
    final color = isGranted ? AppColors.purple400 : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isGranted ? 'Granted' : 'Not granted',
        style: AppTextStyles.labelSmall.copyWith(color: color),
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
            SizedBox(
              width: 140,
              child: SecondaryButton(onPressed: onAction, label: actionLabel!),
            ),
          ],
        ],
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
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
