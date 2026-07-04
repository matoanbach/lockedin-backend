import 'package:flutter/material.dart';

/// Spacing constants following the design system.
/// Based on a 4px base unit with Tailwind-like scale.
class Spacing {
  Spacing._();

  // === Base Spacing Units ===
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // === Page Padding ===
  /// Standard page horizontal padding (p-6 = 24px)
  static const double pagePadding = 24.0;

  /// Standard section vertical gap
  static const double sectionGap = 24.0;

  // === Card Spacing ===
  static const double cardPadding = 20.0;
  static const double cardPaddingLarge = 24.0;
  static const double cardGap = 12.0;

  // === Border Radius ===
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusFull = 9999.0;

  // === Edge Insets Presets ===
  static const EdgeInsets page = EdgeInsets.all(pagePadding);
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: pagePadding,
  );
  static const EdgeInsets card = EdgeInsets.all(cardPadding);
  static const EdgeInsets cardLarge = EdgeInsets.all(cardPaddingLarge);

  // === Gaps as SizedBox ===
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl, width: xxl);
  static const SizedBox gapSection = SizedBox(height: sectionGap);

  // === Vertical Gaps ===
  static const SizedBox verticalXs = SizedBox(height: xs);
  static const SizedBox verticalSm = SizedBox(height: sm);
  static const SizedBox verticalMd = SizedBox(height: md);
  static const SizedBox verticalLg = SizedBox(height: lg);
  static const SizedBox verticalXl = SizedBox(height: xl);
  static const SizedBox verticalXxl = SizedBox(height: xxl);

  // === Horizontal Gaps ===
  static const SizedBox horizontalXs = SizedBox(width: xs);
  static const SizedBox horizontalSm = SizedBox(width: sm);
  static const SizedBox horizontalMd = SizedBox(width: md);
  static const SizedBox horizontalLg = SizedBox(width: lg);
  static const SizedBox horizontalXl = SizedBox(width: xl);

  // === Common Border Radii ===
  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  static BorderRadius get borderRadiusXxl => BorderRadius.circular(radiusXxl);
  static BorderRadius get borderRadiusFull => BorderRadius.circular(radiusFull);
}
