import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/rules_provider.dart';

/// Screen for managing lockdown rules.
class LockdownRulesScreen extends ConsumerStatefulWidget {
  const LockdownRulesScreen({super.key});

  @override
  ConsumerState<LockdownRulesScreen> createState() =>
      _LockdownRulesScreenState();
}

class _LockdownRulesScreenState extends ConsumerState<LockdownRulesScreen> {
  bool _showLockedState = false;

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(lockdownRulesProvider);

    if (_showLockedState) {
      return _LockedStateView(
        onBack: () => setState(() => _showLockedState = false),
      );
    }

    return rulesAsync.when(
      data: (rules) {
        final activeCount = rules.where((rule) => rule.enabled).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: Spacing.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(
                    title: 'Lockdown Rules',
                    subtitle: 'Set limits for individual apps',
                    onBack: () => context.pop(),
                    label: 'HLR-2',
                  ),
                  Spacing.verticalXxl,
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
                  if (rules.isEmpty)
                    const InfoCard(
                      message:
                          'No backend rules exist yet. Create one through the API or add the in-app editor next.',
                      icon: 'i',
                      type: InfoCardType.info,
                    ),
                  ...rules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RuleCard(
                        rule: rule,
                        onToggle: () async {
                          try {
                            await ref
                                .read(lockdownRulesProvider.notifier)
                                .toggleRule(rule.id);
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
                          }
                        },
                      ),
                    ),
                  ),
                  Spacing.verticalLg,
                  SecondaryButton(
                    onPressed: () => setState(() => _showLockedState = true),
                    label: 'Preview Locked State',
                    icon: Icons.lock_outline,
                  ),
                  Spacing.verticalXxl,
                  DashedCard(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Rule creation UI is next. The backend is ready for it.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icons.add,
                    title: 'Add New Rule',
                    subtitle: 'Set limits for more apps',
                  ),
                  Spacing.verticalXxl,
                  const InfoCard(
                    message:
                        'Apps will be blocked when you reach your time limit. Lockdown resets at midnight.',
                    icon: '💡',
                    type: InfoCardType.info,
                  ),
                  Spacing.verticalLg,
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const _RulesLoadingState(),
      error: (error, _) => _RulesLoadingState(
        errorMessage: describeApiError(error),
        onRetry: () {
          ref.read(lockdownRulesProvider.notifier).refresh();
        },
      ),
    );
  }
}

class _RulesLoadingState extends StatelessWidget {
  const _RulesLoadingState({this.errorMessage, this.onRetry});

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
                  hasError ? 'Could not load rules' : 'Loading rules',
                  style: AppTextStyles.titleLarge,
                ),
                Spacing.verticalSm,
                Text(
                  errorMessage ?? 'Fetching your current backend rule set.',
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

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
  });

  final LockdownRule rule;
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Rule editing UI is next. Backend PATCH support is already ready.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
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
