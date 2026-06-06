import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// Progress bar with customizable color.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
    this.backgroundColor,
    this.borderRadius,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackgroundLight,
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: constraints.maxWidth * value.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  color: color ?? AppColors.primary,
                  borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Vertical bar for charts.
class VerticalBar extends StatelessWidget {
  const VerticalBar({
    super.key,
    required this.value,
    this.maxValue = 1.0,
    this.color,
    this.backgroundColor,
    this.width = 12,
  });

  final double value;
  final double maxValue;
  final Color? color;
  final Color? backgroundColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(width / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: constraints.maxHeight * percentage,
                width: width,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color ?? AppColors.purple400,
                      AppColors.purple600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(width / 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Circular progress indicator with center text.
class CircularProgress extends StatelessWidget {
  const CircularProgress({
    super.key,
    required this.value,
    this.size = 80,
    this.strokeWidth = 8,
    this.color,
    this.backgroundColor,
    this.child,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            backgroundColor: backgroundColor ?? AppColors.cardBackgroundLight,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppColors.primary,
            ),
          ),
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}
