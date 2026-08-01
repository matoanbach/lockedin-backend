import 'package:flutter/material.dart';

import '../../../../core/formatters/minute_copy.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/rules_provider.dart';

class AppLimitUsageCard extends StatelessWidget {
  const AppLimitUsageCard({
    super.key,
    required this.appName,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.limitMinutes,
    required this.status,
    required this.reminderThresholdMinutes,
    required this.onToggle,
    required this.onEdit,
  });

  final String appName;
  final IconData icon;
  final Color color;
  final bool enabled;
  final int limitMinutes;
  final RuleStatusData? status;
  final int reminderThresholdMinutes;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasStatus = status != null;
    final usedMilliseconds = status?.usedMilliseconds ?? 0;
    final remainingMilliseconds =
        status?.remainingMilliseconds ?? limitMinutes * 60000;
    final showReminderWarning =
        enabled &&
        hasStatus &&
        status!.status == 'approaching_limit' &&
        remainingMilliseconds > 0 &&
        remainingMilliseconds <= reminderThresholdMinutes * 60000;
    final effectiveStatus = status?.status;
    final statusColor = statusColorFor(effectiveStatus, color);
    final statusLabel = statusLabelFor(effectiveStatus, enabled);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon: icon, color: color),
              Spacing.horizontalLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appName, style: AppTextStyles.titleMedium),
                    Spacing.verticalXs,
                    Text(
                      hasStatus
                          ? '${formatLimitMilliseconds(usedMilliseconds)} used'
                          : 'Waiting for current usage',
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
              AppSwitch(value: enabled, onChanged: (_) => onToggle()),
            ],
          ),
          Spacing.verticalMd,
          _LimitSummary(
            limitMinutes: limitMinutes,
            usedMilliseconds: usedMilliseconds,
            remainingMilliseconds: remainingMilliseconds,
            hasStatus: hasStatus,
          ),
          if (showReminderWarning) ...[
            Spacing.verticalMd,
            _ReminderWarningLabel(milliseconds: remainingMilliseconds),
          ],
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
                Flexible(
                  child: Text(
                    statusDetailText(status!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Spacing.horizontalSm,
                Text(
                  '${status!.progressPercent}%',
                  style: AppTextStyles.labelSmall.copyWith(color: statusColor),
                ),
              ],
            ),
          ],
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
                    Icon(
                      enabled ? Icons.lock_outline : Icons.lock_open_outlined,
                      color: enabled
                          ? AppColors.purple400
                          : AppColors.textMuted,
                      size: 16,
                    ),
                    Spacing.horizontalSm,
                    Text(
                      enabled
                          ? hasStatus && status!.isBlockedNow
                                ? 'Over limit now'
                                : 'Lockdown enabled'
                          : 'Rule disabled',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: enabled && hasStatus && status!.isBlockedNow
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Edit rule',
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
      ),
    );
  }
}

class ReminderThresholdCard extends StatelessWidget {
  const ReminderThresholdCard({
    super.key,
    required this.controller,
    required this.thresholdMinutes,
    required this.onApply,
  });

  final TextEditingController controller;
  final int thresholdMinutes;
  final ValueChanged<int> onApply;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reminder Threshold', style: AppTextStyles.titleMedium),
          Spacing.verticalXs,
          Text(
            'Notify me when I have ${formatMinuteCount(thresholdMinutes)} left',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          Spacing.verticalMd,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes left',
                    hintText: '20',
                  ),
                ),
              ),
              Spacing.horizontalMd,
              SizedBox(
                width: 96,
                child: SecondaryButton(
                  height: 48,
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());
                    if (value == null || value <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a reminder threshold above 0.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    onApply(value);
                  },
                  label: 'Apply',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReminderBanner extends StatelessWidget {
  const ReminderBanner({
    super.key,
    required this.status,
    required this.onShowPopup,
  });

  final RuleStatusData status;
  final VoidCallback onShowPopup;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.warning.withValues(alpha: 0.45),
      color: AppColors.warningLight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          Spacing.horizontalMd,
          Expanded(
            child: Text(
              reminderPopupText(status),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
          TextButton(onPressed: onShowPopup, child: const Text('Show')),
        ],
      ),
    );
  }
}

class _LimitSummary extends StatelessWidget {
  const _LimitSummary({
    required this.limitMinutes,
    required this.usedMilliseconds,
    required this.remainingMilliseconds,
    required this.hasStatus,
  });

  final int limitMinutes;
  final int usedMilliseconds;
  final int remainingMilliseconds;
  final bool hasStatus;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _MetricPill(
          label: 'Used',
          value: formatLimitMilliseconds(usedMilliseconds),
        ),
        _MetricPill(label: 'Limit', value: formatLimitMinutes(limitMinutes)),
        _MetricPill(
          label: 'Left',
          value: hasStatus
              ? formatLimitMilliseconds(remainingMilliseconds)
              : 'Pending',
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ReminderWarningLabel extends StatelessWidget {
  const _ReminderWarningLabel({required this.milliseconds});

  final int milliseconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 16,
          ),
          Spacing.horizontalXs,
          Text(
            '${formatElapsedMilliseconds(milliseconds)} left',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
          ),
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

String formatLimitMinutes(int minutes) {
  final safeMinutes = minutes < 0 ? 0 : minutes;
  final hours = safeMinutes ~/ 60;
  final remainder = safeMinutes % 60;
  if (hours == 0) {
    return '${remainder}m';
  }
  if (remainder == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainder}m';
}

String formatLimitMilliseconds(int milliseconds) {
  if (milliseconds > 0 && milliseconds < 60000) {
    return '<1m';
  }
  return formatLimitMinutes(milliseconds ~/ 60000);
}

String reminderPopupText(RuleStatusData status) {
  return 'Reminder: You have ${formatElapsedMilliseconds(status.remainingMilliseconds)} left on ${status.appName}.';
}

RuleStatusData? firstReminderStatusFor(
  Iterable<RuleStatusData> statuses,
  int reminderThresholdMinutes,
) {
  for (final status in statuses) {
    if (!status.enabled ||
        status.status != 'approaching_limit' ||
        status.remainingMilliseconds <= 0) {
      continue;
    }
    if (status.remainingMilliseconds <= reminderThresholdMinutes * 60000) {
      return status;
    }
  }
  return null;
}

Color statusColorFor(String? status, Color fallbackColor) {
  return switch (status) {
    'over_limit' => AppColors.error,
    'at_limit' => AppColors.warning,
    'approaching_limit' => AppColors.warning,
    'disabled' => AppColors.textMuted,
    'under_limit' => AppColors.success,
    _ => fallbackColor,
  };
}

String statusLabelFor(String? status, bool enabled) {
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

String statusDetailText(RuleStatusData status) {
  return switch (status.status) {
    'over_limit' => 'Over today\'s ${status.limitMinutes}-minute limit',
    'at_limit' => 'Daily limit reached',
    'approaching_limit' =>
      '${formatElapsedMilliseconds(status.remainingMilliseconds)} remaining today',
    'under_limit' =>
      '${formatElapsedMilliseconds(status.remainingMilliseconds)} remaining today',
    'disabled' => 'Rule disabled. Usage is still tracked.',
    _ => 'Waiting for current usage status.',
  };
}
