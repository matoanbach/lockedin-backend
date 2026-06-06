import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// Standard card component matching the React app's card style.
/// Equivalent to bg-white/5 border border-white/10 rounded-2xl
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? Spacing.borderRadiusLg;

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.cardBackground) : null,
        gradient: gradient,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: borderColor ?? AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: Padding(
            padding: padding ?? Spacing.card,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Gradient card for highlighted content.
/// Matches bg-gradient-to-br from-purple-600/20 to-purple-400/10
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.colors,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ??
              [
                AppColors.purple600.withValues(alpha: 0.2),
                AppColors.purple400.withValues(alpha: 0.1),
              ],
        ),
        borderRadius: Spacing.borderRadiusXxl,
        border: Border.all(
          color: borderColor ?? AppColors.borderPurple,
        ),
      ),
      padding: padding ?? Spacing.cardLarge,
      child: child,
    );
  }
}

/// Info card with colored accent.
/// Used for tips, warnings, success messages.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.message,
    this.icon,
    this.type = InfoCardType.info,
  });

  final String message;
  final String? icon;
  final InfoCardType type;

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, textColor) = switch (type) {
      InfoCardType.info => (
          AppColors.infoLight,
          AppColors.info.withValues(alpha: 0.3),
          AppColors.info,
        ),
      InfoCardType.success => (
          AppColors.successLight,
          AppColors.success.withValues(alpha: 0.3),
          AppColors.success,
        ),
      InfoCardType.warning => (
          AppColors.warningLight,
          AppColors.warning.withValues(alpha: 0.3),
          AppColors.warning,
        ),
      InfoCardType.error => (
          AppColors.errorLight,
          AppColors.error.withValues(alpha: 0.3),
          AppColors.error,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: Spacing.borderRadiusLg,
        border: Border.all(color: borderColor),
      ),
      child: Text(
        '${icon ?? _defaultIcon} $message',
        style: AppTextStyles.bodySmall.copyWith(color: textColor),
      ),
    );
  }

  String get _defaultIcon => switch (type) {
        InfoCardType.info => '💡',
        InfoCardType.success => '✓',
        InfoCardType.warning => '⚠️',
        InfoCardType.error => '❌',
      };
}

enum InfoCardType { info, success, warning, error }

/// Dashed border card for "Add new" actions.
class DashedCard extends StatelessWidget {
  const DashedCard({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Spacing.borderRadiusLg,
      child: Container(
        padding: Spacing.card,
        decoration: BoxDecoration(
          borderRadius: Spacing.borderRadiusLg,
          border: Border.all(
            color: AppColors.border,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            Spacing.verticalMd,
            Text(title, style: AppTextStyles.titleMedium),
            if (subtitle != null) ...[
              Spacing.verticalXs,
              Text(
                subtitle!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
