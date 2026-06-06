import 'package:flutter/material.dart';

/// Design tokens extracted from the React/Figma design system.
/// All colors follow the original dark theme aesthetic.
class AppColors {
  AppColors._();

  // === Primary Colors ===
  static const Color primary = Color(0xFF7A5AF8);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF6B4FD9);

  // === Purple Shades (Brand) ===
  static const Color purple100 = Color(0xFFDDD6FE);
  static const Color purple200 = Color(0xFFC4B5FD);
  static const Color purple300 = Color(0xFFA78BFA);
  static const Color purple400 = Color(0xFF9B7AF8);
  static const Color purple500 = Color(0xFF7A5AF8);
  static const Color purple600 = Color(0xFF7C3AED);
  static const Color purple700 = Color(0xFF6D28D9);

  // === Background Colors ===
  static const Color background = Color(0xFF1C1C1C);
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF2A2A2A);
  static const Color surfaceVariant = Color(0xFF1E1E1E);

  // === Card & Container Colors ===
  /// Equivalent to bg-white/5
  static Color get cardBackground => Colors.white.withValues(alpha: 0.05);

  /// Equivalent to bg-white/10
  static Color get cardBackgroundLight => Colors.white.withValues(alpha: 0.10);

  /// Gradient card background
  static const Color gradientPurpleStart = Color(0x337C3AED);
  static const Color gradientPurpleEnd = Color(0x1AA78BFA);

  // === Border Colors ===
  /// Equivalent to border-white/10
  static Color get border => Colors.white.withValues(alpha: 0.10);

  /// Equivalent to border-purple-500/30
  static Color get borderPurple => purple500.withValues(alpha: 0.30);

  /// Equivalent to border-purple-500/50
  static Color get borderPurpleStrong => purple500.withValues(alpha: 0.50);

  // === Text Colors ===
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1); // slate-300
  static const Color textTertiary = Color(0xFF94A3B8); // slate-400
  static const Color textMuted = Color(0xFF64748B); // slate-500

  // === Status Colors ===
  static const Color success = Color(0xFF4ADE80); // green-400
  static const Color successLight = Color(0x1A4ADE80); // green-500/10
  static const Color error = Color(0xFFF87171); // red-400
  static const Color errorLight = Color(0x33F87171); // red-500/20
  static const Color warning = Color(0xFFFBBF24); // yellow-400
  static const Color warningLight = Color(0x1AFBBF24); // yellow-500/10
  static const Color info = Color(0xFF60A5FA); // blue-400
  static const Color infoLight = Color(0x1A3B82F6); // blue-500/10

  // === Chart Colors (from design tokens) ===
  static const Color chart1 = Color(0xFF7A5AF8); // Purple
  static const Color chart2 = Color(0xFFA78BFA); // Light purple
  static const Color chart3 = Color(0xFFC4B5FD); // Lighter purple
  static const Color chart4 = Color(0xFFDDD6FE); // Lightest purple

  // === App-specific Colors ===
  static const Color instagram = Color(0xFFE4405F);
  static const Color youtube = Color(0xFFFF0000);
  static const Color messages = Color(0xFF00B900);

  // === Switch & Input Colors ===
  static const Color switchTrack = Color(0xFFCBCED4);
  static Color get inputBackground => Colors.white.withValues(alpha: 0.05);

  // === Transparent Overlays ===
  static Color get overlay => Colors.black.withValues(alpha: 0.50);
  static Color get overlayLight => Colors.black.withValues(alpha: 0.30);
}
