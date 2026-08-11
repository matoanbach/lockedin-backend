import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/route_back_fallback.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../enforcement/data/live_intervention_provider.dart';
import '../../data/rules_provider.dart';
import '../widgets/app_limit_warning.dart';

/// Screen for managing lockdown rules.
class LockdownRulesScreen extends ConsumerStatefulWidget {
  const LockdownRulesScreen({
    super.key,
    this.openCreateForm = false,
    this.installedAppsLoader,
  });

  final bool openCreateForm;
  final Future<List<InstalledRuleApp>> Function()? installedAppsLoader;

  @override
  ConsumerState<LockdownRulesScreen> createState() =>
      _LockdownRulesScreenState();
}

class _LockdownRulesScreenState extends ConsumerState<LockdownRulesScreen> {
  bool _didAutoOpenCreateForm = false;
  int _reminderThresholdMinutes = 30;
  late final TextEditingController _reminderThresholdController;

  @override
  void initState() {
    super.initState();
    _reminderThresholdController = TextEditingController(
      text: '$_reminderThresholdMinutes',
    );
  }

  @override
  void dispose() {
    _reminderThresholdController.dispose();
    super.dispose();
  }

  Future<void> _openRuleSheet({LockdownRule? initialRule}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RuleFormSheet(
        initialRule: initialRule,
        installedAppsLoader: widget.installedAppsLoader,
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

    return rulesAsync.when(
      data: (rules) {
        if (widget.openCreateForm && !_didAutoOpenCreateForm) {
          _didAutoOpenCreateForm = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openRuleSheet();
            }
          });
        }
        final activeCount = rules.where((rule) => rule.enabled).length;
        final statusMap = {
          for (final status
              in ruleStatusesAsync.asData?.value ?? const <RuleStatusData>[])
            status.ruleId: status,
        };
        final reminderStatus = firstReminderStatusFor(
          statusMap.values,
          _reminderThresholdMinutes,
        );

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
                    onBack: () => RouteBackFallback.navigate(
                      context,
                      AppRoutes.dashboard,
                    ),
                  ),
                  Spacing.verticalXxl,
                  if (reminderStatus != null) ...[
                    ReminderBanner(
                      status: reminderStatus,
                      onShowPopup: () => _showReminderSnackBar(reminderStatus),
                    ),
                    Spacing.verticalXxl,
                  ],
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
                  ReminderThresholdCard(
                    controller: _reminderThresholdController,
                    thresholdMinutes: _reminderThresholdMinutes,
                    onApply: (value) {
                      setState(() => _reminderThresholdMinutes = value);
                    },
                  ),
                  Spacing.verticalMd,
                  ...rules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Builder(
                        builder: (context) {
                          final status = statusMap[rule.id];

                          return AppLimitUsageCard(
                            appName: rule.appName,
                            icon: rule.icon,
                            color: rule.color,
                            enabled: rule.enabled,
                            limitMinutes:
                                status?.limitMinutes ?? rule.limitMinutes,
                            status: status,
                            reminderThresholdMinutes: _reminderThresholdMinutes,
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
                          );
                        },
                      ),
                    ),
                  ),
                  Spacing.verticalXxl,
                  DashedCard(
                    onTap: () async {
                      await _openRuleSheet();
                    },
                    icon: Icons.add,
                    title: 'Add New Rule',
                    subtitle: 'Choose any installed app and set a daily limit',
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

  void _showReminderSnackBar(RuleStatusData status) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reminderPopupText(status)),
        behavior: SnackBarBehavior.floating,
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

class RuleFormValue {
  const RuleFormValue({
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

class RuleFormSheet extends StatefulWidget {
  const RuleFormSheet({
    super.key,
    required this.onSubmit,
    this.initialRule,
    this.onDelete,
    this.installedAppsLoader,
  });

  final LockdownRule? initialRule;
  final Future<void> Function(RuleFormValue value) onSubmit;
  final Future<void> Function()? onDelete;
  final Future<List<InstalledRuleApp>> Function()? installedAppsLoader;

  @override
  State<RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends State<RuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _appNameController;
  late final TextEditingController _appIdController;
  late final TextEditingController _limitMinutesController;
  late bool _enabled;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  bool _showAdvancedAppId = false;
  String? _selectedKnownAppId;
  String? _submissionError;
  late Future<List<InstalledRuleApp>> _installedAppsFuture;

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
    _installedAppsFuture = _loadInstalledApps();
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

  Future<List<InstalledRuleApp>> _loadInstalledApps() {
    return (widget.installedAppsLoader ?? loadLaunchableRuleApps)();
  }

  void _retryInstalledApps() {
    setState(() => _installedAppsFuture = _loadInstalledApps());
  }

  void _applyInstalledApp(InstalledRuleApp app) {
    final knownApp = knownRuleAppFor(app.appId, app.displayName);
    setState(() {
      _selectedKnownAppId = knownApp?.appId;
      _showAdvancedAppId = false;
      _appNameController.text = app.displayName;
      _appIdController.text = app.appId;
    });
  }

  Future<void> _openInstalledAppPicker(List<InstalledRuleApp> apps) async {
    final selected = await showSearch<InstalledRuleApp?>(
      context: context,
      delegate: _InstalledAppSearchDelegate(apps),
    );
    if (selected != null && mounted) {
      _applyInstalledApp(selected);
    }
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
          content: Text('Choose an installed app or enter an app identifier.'),
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

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.onSubmit(
        RuleFormValue(
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

      setState(() => _submissionError = describeApiError(error));
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
                                          : 'Choose any launchable app installed on this device, then set its daily limit.',
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
                            Spacing.verticalLg,
                            Text(
                              'All Installed Apps',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Spacing.verticalXs,
                            Text(
                              'Search every launchable app on this device.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            Spacing.verticalSm,
                            FutureBuilder<List<InstalledRuleApp>>(
                              future: _installedAppsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState !=
                                    ConnectionState.done) {
                                  return const LinearProgressIndicator();
                                }
                                if (snapshot.hasError) {
                                  return AppCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Installed apps could not be loaded. You can still enter an identifier manually.',
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _retryInstalledApps,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                final apps =
                                    snapshot.data ?? const <InstalledRuleApp>[];
                                return SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey('installed-app-picker'),
                                    onPressed: apps.isEmpty
                                        ? null
                                        : () => _openInstalledAppPicker(apps),
                                    icon: const Icon(Icons.search),
                                    label: Text(
                                      apps.isEmpty
                                          ? 'No launchable apps found'
                                          : 'Search ${apps.length} installed apps',
                                    ),
                                  ),
                                );
                              },
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
                          if (_submissionError != null) ...[
                            Spacing.verticalLg,
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                key: const ValueKey('rule-form-error'),
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.errorLight,
                                  borderRadius: Spacing.borderRadiusMd,
                                  border: Border.all(color: AppColors.error),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: AppColors.error,
                                    ),
                                    Spacing.horizontalSm,
                                    Expanded(
                                      child: Text(
                                        _submissionError!,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

class _InstalledAppSearchDelegate extends SearchDelegate<InstalledRuleApp?> {
  _InstalledAppSearchDelegate(this.apps);

  final List<InstalledRuleApp> apps;

  @override
  String get searchFieldLabel => 'Search installed apps';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear search',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final matches = normalizedQuery.isEmpty
        ? apps
        : apps
              .where(
                (app) =>
                    app.displayName.toLowerCase().contains(normalizedQuery) ||
                    app.appId.toLowerCase().contains(normalizedQuery),
              )
              .toList();

    if (matches.isEmpty) {
      return const Center(child: Text('No installed apps match your search.'));
    }

    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final app = matches[index];
        return ListTile(
          leading: const Icon(Icons.apps),
          title: Text(app.displayName),
          subtitle: Text(app.appId),
          onTap: () => close(context, app),
        );
      },
    );
  }
}
