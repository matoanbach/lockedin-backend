import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../enforcement/data/live_intervention_provider.dart';
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

  Future<void> _openRuleSheet({LockdownRule? initialRule}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RuleFormSheet(
        initialRule: initialRule,
        onSubmit: (value) async {
          if (initialRule == null) {
            await ref
                .read(lockdownRulesProvider.notifier)
                .createRule(
                  appId: value.appId,
                  appName: value.appName,
                  limitMinutes: value.limitMinutes,
                  enabled: value.enabled,
                );
            await ref
                .read(liveInterventionProvider.notifier)
                .refreshRuleStateCache();
            return;
          }

          await ref
              .read(lockdownRulesProvider.notifier)
              .updateRule(
                ruleId: initialRule.id,
                appName: value.appName,
                limitMinutes: value.limitMinutes,
                enabled: value.enabled,
              );
          await ref
              .read(liveInterventionProvider.notifier)
              .refreshRuleStateCache();
        },
        onDelete: initialRule == null
            ? null
            : () async {
                await ref
                    .read(lockdownRulesProvider.notifier)
                    .deleteRule(initialRule.id);
                await ref
                    .read(liveInterventionProvider.notifier)
                    .refreshRuleStateCache();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(lockdownRulesProvider);
    final ruleStatusesAsync = ref.watch(ruleStatusesProvider);

    if (_showLockedState) {
      return _LockedStateView(
        onBack: () => setState(() => _showLockedState = false),
      );
    }

    return rulesAsync.when(
      data: (rules) {
        final activeCount = rules.where((rule) => rule.enabled).length;
        final statusMap = {
          for (final status
              in ruleStatusesAsync.asData?.value ?? const <RuleStatusData>[])
            status.ruleId: status,
        };

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
                          'No backend rules exist yet. Add one below and LockdIn will persist it for future sessions.',
                      icon: 'i',
                      type: InfoCardType.info,
                    ),
                  if (ruleStatusesAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InfoCard(
                        message: describeApiError(ruleStatusesAsync.error!),
                        icon: '!',
                        type: InfoCardType.warning,
                      ),
                    ),
                  ...rules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RuleCard(
                        rule: rule,
                        status: statusMap[rule.id],
                        onToggle: () async {
                          try {
                            await ref
                                .read(lockdownRulesProvider.notifier)
                                .toggleRule(rule.id);
                            await ref
                                .read(liveInterventionProvider.notifier)
                                .refreshRuleStateCache();
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
                        onEdit: () async {
                          await _openRuleSheet(initialRule: rule);
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
                    onTap: () async {
                      await _openRuleSheet();
                    },
                    icon: Icons.add,
                    title: 'Add New Rule',
                    subtitle: 'Use real app names like Instagram',
                  ),
                  Spacing.verticalXxl,
                  const InfoCard(
                    message:
                        'LockdIn stores a friendly app name for the UI and a stable app identifier behind the scenes for accurate matching.',
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
                  const Icon(Icons.cloud_off, color: AppColors.error, size: 36),
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
    required this.status,
    required this.onToggle,
    required this.onEdit,
  });

  final LockdownRule rule;
  final RuleStatusData? status;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasStatus = status != null;
    final statusColor = _statusColor(status?.status, rule.color);
    final statusLabel = _statusLabel(status?.status, rule.enabled);

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(icon: rule.icon, color: rule.color),
              Spacing.horizontalLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.appName, style: AppTextStyles.titleMedium),
                    Spacing.verticalXs,
                    Text(
                      hasStatus
                          ? status!.formattedUsage
                          : 'Block after ${rule.formattedLimit}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasStatus) ...[
                Spacing.horizontalMd,
                _StatusChip(label: statusLabel, color: statusColor),
              ],
              AppSwitch(value: rule.enabled, onChanged: (_) => onToggle()),
            ],
          ),
          if (hasStatus) ...[
            Spacing.verticalMd,
            AppProgressBar(
              value: status!.progressValue,
              color: statusColor,
              backgroundColor: AppColors.cardBackgroundLight,
              height: 8,
            ),
            Spacing.verticalSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _statusDetailText(status!),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${status!.progressPercent}%',
                  style: AppTextStyles.labelSmall.copyWith(color: statusColor),
                ),
              ],
            ),
          ],
          if (rule.enabled) ...[
            Spacing.verticalMd,
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
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
                        hasStatus && status!.isBlockedNow
                            ? 'Over limit now'
                            : 'Lockdown enabled',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: hasStatus && status!.isBlockedNow
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: onEdit,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

Color _statusColor(String? status, Color fallbackColor) {
  return switch (status) {
    'over_limit' => AppColors.error,
    'at_limit' => AppColors.warning,
    'approaching_limit' => AppColors.warning,
    'disabled' => AppColors.textMuted,
    'under_limit' => AppColors.success,
    _ => fallbackColor,
  };
}

String _statusLabel(String? status, bool enabled) {
  if (!enabled) {
    return 'Disabled';
  }

  return switch (status) {
    'over_limit' => 'Over Limit',
    'at_limit' => 'At Limit',
    'approaching_limit' => 'Approaching',
    'under_limit' => 'Under Limit',
    'disabled' => 'Disabled',
    _ => 'Pending',
  };
}

String _statusDetailText(RuleStatusData status) {
  return switch (status.status) {
    'over_limit' =>
      '${status.usedMinutes - status.limitMinutes} min over today',
    'at_limit' => 'Daily limit reached',
    'approaching_limit' => '${status.remainingMinutes} min remaining today',
    'under_limit' => '${status.remainingMinutes} min remaining today',
    'disabled' => 'Rule disabled. Usage is still tracked.',
    _ => 'Waiting for current usage status.',
  };
}

class _RuleFormValue {
  const _RuleFormValue({
    required this.appId,
    required this.appName,
    required this.limitMinutes,
    required this.enabled,
  });

  final String appId;
  final String appName;
  final int limitMinutes;
  final bool enabled;
}

class _RuleFormSheet extends StatefulWidget {
  const _RuleFormSheet({
    required this.onSubmit,
    this.initialRule,
    this.onDelete,
  });

  final LockdownRule? initialRule;
  final Future<void> Function(_RuleFormValue value) onSubmit;
  final Future<void> Function()? onDelete;

  @override
  State<_RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends State<_RuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _appNameController;
  late final TextEditingController _appIdController;
  late final TextEditingController _limitMinutesController;
  late bool _enabled;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  bool _showAdvancedAppId = false;
  String? _selectedKnownAppId;

  bool get _isEditing => widget.initialRule != null;

  @override
  void initState() {
    super.initState();
    final initialRule = widget.initialRule;
    final knownApp = initialRule == null
        ? null
        : knownRuleAppFor(initialRule.appId, initialRule.appName);

    _appNameController = TextEditingController(
      text: initialRule?.appName ?? '',
    );
    _appIdController = TextEditingController(text: initialRule?.appId ?? '');
    _limitMinutesController = TextEditingController(
      text: initialRule?.limitMinutes.toString() ?? '60',
    );
    _enabled = initialRule?.enabled ?? true;
    _selectedKnownAppId = knownApp?.appId;
    _showAdvancedAppId = _isEditing;
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _appIdController.dispose();
    _limitMinutesController.dispose();
    super.dispose();
  }

  KnownRuleApp? get _selectedKnownApp {
    final appId = _selectedKnownAppId;
    if (appId == null) {
      return null;
    }

    for (final app in knownRuleApps) {
      if (app.appId == appId) {
        return app;
      }
    }

    return null;
  }

  void _applyKnownApp(KnownRuleApp app) {
    setState(() {
      _selectedKnownAppId = app.appId;
      _showAdvancedAppId = false;
      _appNameController.text = app.displayName;
      _appIdController.text = app.appId;
    });
  }

  void _handleAppNameChanged(String value) {
    if (_isEditing) {
      return;
    }

    final selectedKnownApp = _selectedKnownApp;
    if (selectedKnownApp == null ||
        value.trim() == selectedKnownApp.displayName) {
      return;
    }

    setState(() {
      _selectedKnownAppId = null;
      if (_appIdController.text == selectedKnownApp.appId) {
        _appIdController.clear();
      }
      _showAdvancedAppId = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final appId = _appIdController.text.trim();
    if (appId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a common app or enter an app identifier.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _showAdvancedAppId = true);
      return;
    }

    final limitMinutes = int.tryParse(_limitMinutesController.text.trim());
    if (limitMinutes == null || limitMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid time limit in minutes.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        _RuleFormValue(
          appId: appId,
          appName: _appNameController.text.trim(),
          limitMinutes: limitMinutes,
          enabled: _enabled,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeApiError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.onDelete == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete rule'),
        content: const Text(
          'This will remove the rule from the backend. You can add it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isDeleting = true);

    try {
      await widget.onDelete!.call();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeApiError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 24, 12, bottomInset + 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Spacing.verticalMd,
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isEditing ? 'Edit Rule' : 'Create Rule',
                                      style: AppTextStyles.headlineMedium,
                                    ),
                                    Spacing.verticalXs,
                                    Text(
                                      _isEditing
                                          ? 'Update the limit and display name for this app.'
                                          : 'Pick a real app name like Instagram, then save the matching backend rule.',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _isSubmitting || _isDeleting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          if (!_isEditing) ...[
                            Spacing.verticalLg,
                            Text(
                              'Common Apps',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Spacing.verticalSm,
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final app in knownRuleApps)
                                  _PresetAppChip(
                                    app: app,
                                    isSelected:
                                        _selectedKnownAppId == app.appId,
                                    onTap: () => _applyKnownApp(app),
                                  ),
                              ],
                            ),
                          ],
                          Spacing.verticalLg,
                          TextFormField(
                            controller: _appNameController,
                            onChanged: _handleAppNameChanged,
                            style: AppTextStyles.bodyMedium,
                            decoration: InputDecoration(
                              labelText: 'App Name',
                              hintText: 'Instagram',
                              helperText: 'Friendly name shown in the UI',
                              helperStyle: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter an app name';
                              }
                              return null;
                            },
                          ),
                          Spacing.verticalMd,
                          if (_isEditing)
                            AppCard(
                              padding: const EdgeInsets.all(16),
                              color: AppColors.cardBackgroundLight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'App Identifier',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  Spacing.verticalXs,
                                  Text(
                                    _appIdController.text,
                                    style: AppTextStyles.titleMedium,
                                  ),
                                  Spacing.verticalXs,
                                  Text(
                                    'This stays stable so LockdIn can match the correct app later.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!_isEditing) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showAdvancedAppId = !_showAdvancedAppId;
                                  });
                                },
                                icon: Icon(
                                  _showAdvancedAppId
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                label: Text(
                                  _showAdvancedAppId
                                      ? 'Hide App Identifier'
                                      : 'Enter App Identifier Manually',
                                ),
                              ),
                            ),
                            if (_showAdvancedAppId)
                              TextFormField(
                                controller: _appIdController,
                                style: AppTextStyles.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: 'App Identifier',
                                  hintText: 'com.instagram.android',
                                  helperText:
                                      'Required for custom apps or when no preset app matches.',
                                  helperStyle: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                          Spacing.verticalMd,
                          TextFormField(
                            controller: _limitMinutesController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: AppTextStyles.bodyMedium,
                            decoration: const InputDecoration(
                              labelText: 'Daily Limit (minutes)',
                              hintText: '60',
                            ),
                            validator: (value) {
                              final minutes = int.tryParse(
                                (value ?? '').trim(),
                              );
                              if (minutes == null || minutes <= 0) {
                                return 'Enter a limit greater than 0';
                              }
                              return null;
                            },
                          ),
                          Spacing.verticalSm,
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [30, 60, 90, 120, 180].map((minutes) {
                              final isSelected =
                                  _limitMinutesController.text == '$minutes';

                              return ChoiceChip(
                                label: Text('$minutes min'),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _limitMinutesController.text = '$minutes';
                                  });
                                },
                                selectedColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                              );
                            }).toList(),
                          ),
                          Spacing.verticalLg,
                          SettingsTile(
                            title: 'Rule Enabled',
                            subtitle:
                                'Turn this off without deleting the rule.',
                            value: _enabled,
                            onChanged: (value) {
                              setState(() => _enabled = value);
                            },
                          ),
                          Spacing.verticalXxl,
                          PrimaryButton(
                            onPressed: _isSubmitting || _isDeleting
                                ? null
                                : _submit,
                            label: _isEditing ? 'Save Changes' : 'Create Rule',
                            isLoading: _isSubmitting,
                          ),
                          if (widget.onDelete != null) ...[
                            Spacing.verticalMd,
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: _isSubmitting || _isDeleting
                                    ? null
                                    : _delete,
                                icon: _isDeleting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.delete_outline),
                                label: const Text('Delete Rule'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetAppChip extends StatelessWidget {
  const _PresetAppChip({
    required this.app,
    required this.isSelected,
    required this.onTap,
  });

  final KnownRuleApp app;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? app.color.withValues(alpha: 0.2)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? app.color : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(app.icon, color: app.color, size: 16),
            Spacing.horizontalSm,
            Text(app.displayName, style: AppTextStyles.bodySmall),
          ],
        ),
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
                  border: Border.all(color: AppColors.error, width: 4),
                ),
                child: const Center(
                  child: Icon(Icons.lock, size: 48, color: AppColors.error),
                ),
              ),
              Spacing.verticalXxl,
              Text('App Locked', style: AppTextStyles.headlineMedium),
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
              SecondaryButton(onPressed: onBack, label: 'Back to Rules'),
            ],
          ),
        ),
      ),
    );
  }
}
