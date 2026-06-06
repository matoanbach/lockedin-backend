import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// Icon container with colored background.
/// Used throughout the app for feature icons.
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    this.size = 48,
    this.iconSize = 24,
    this.color,
    this.backgroundColor,
    this.borderRadius,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    final effectiveBgColor =
        backgroundColor ?? effectiveColor.withValues(alpha: 0.2);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: borderRadius ?? Spacing.borderRadiusMd,
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: effectiveColor,
        ),
      ),
    );
  }
}

/// Circular icon container.
class CircleIconBox extends StatelessWidget {
  const CircleIconBox({
    super.key,
    required this.icon,
    this.size = 48,
    this.iconSize = 24,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    final effectiveBgColor =
        backgroundColor ?? effectiveColor.withValues(alpha: 0.2);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: effectiveColor,
        ),
      ),
    );
  }
}

/// App usage icon with app-specific color.
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: Spacing.borderRadiusMd,
      ),
      child: Center(
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
