import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../dashboard/data/providers/dashboard_provider.dart';

/// Screen for managing lockdown rules.
class LockdownRulesScreen extends ConsumerStatefulWidget {
  const LockdownRulesScreen({super.key});

  @override
  ConsumerState<LockdownRulesScreen> createState() => _LockdownRulesScreenState();
}

class _LockdownRulesScreenState extends ConsumerState<LockdownRulesScreen> {
  bool _showLockedState = false;

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(lockdownRulesProvider);
    final activeCount = rules.where((r) => r.enabled).length;

    if (_showLockedState) {
      return _LockedStateView(
        onBack: () => setState(() => _showLockedState = false),
      );
    }

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
                title: 'Lockdown Rules',
                subtitle: 'Set limits for individual apps',
                onBack: () => context.pop(),
                label: 'HLR-2',
              ),
              Spacing.verticalXxl,

              // Active Rules Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Rules',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '$activeCount active',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              Spacing.verticalMd,

              // Rules List
              ...rules.map((rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RuleCard(
                      rule: rule,
                      onToggle: () {
                        ref
                            .read(lockdownRulesProvider.notifier)
                            .toggleRule(rule.id);
                      },
                    ),
                  )),
              Spacing.verticalLg,

              // Preview Lock State Button
              SecondaryButton(
                onPressed: () => setState(() => _showLockedState = true),
                label: 'Preview Locked State',
                icon: Icons.lock_outline,
              ),
              Spacing.verticalXxl,

              // Add New Rule
              DashedCard(
                onTap: () {
                  // TODO: Navigate to add rule screen
                },
                icon: Icons.add,
                title: 'Add New Rule',
                subtitle: 'Set limits for more apps',
              ),
              Spacing.verticalXxl,

              // Info Card
              const InfoCard(
                message: 'Apps will be blocked when you reach your time limit. Lockdown resets at midnight.',
                icon: '💡',
                type: InfoCardType.info,
              ),
              Spacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
  });

  final dynamic rule;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(
                icon: rule.icon,
                color: rule.color,
              ),
              Spacing.horizontalLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.appName, style: AppTextStyles.titleMedium),
                    Spacing.verticalXs,
                    Text(
                      'Block after ${rule.formattedLimit}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AppSwitch(
                value: rule.enabled,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
          if (rule.enabled) ...[
            Spacing.verticalMd,
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: AppColors.purple400,
                        size: 16,
                      ),
                      Spacing.horizontalSm,
                      Text(
                        'Lockdown enabled',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Edit rule
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedStateView extends StatelessWidget {
  const _LockedStateView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock Icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.error,
                    width: 4,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock,
                    size: 48,
                    color: AppColors.error,
                  ),
                ),
              ),
              Spacing.verticalXxl,

              // Title
              Text(
                'App Locked',
                style: AppTextStyles.headlineMedium,
              ),
              Spacing.verticalSm,
              Text(
                'You\'ve reached your 2-hour limit for Instagram today.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              Spacing.verticalXxl,

              // Reset Timer
              AppCard(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'Your limit resets in '),
                      TextSpan(
                        text: '6h 24m',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.purple400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Spacing.verticalXxl,

              // Back Button
              SecondaryButton(
                onPressed: onBack,
                label: 'Back to Rules',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
