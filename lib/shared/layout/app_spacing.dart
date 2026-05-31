import 'package:flutter/material.dart';

/// Consistent spacing constants used across the app.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Gaps
  static const SizedBox gapXS = SizedBox(height: xs, width: xs);
  static const SizedBox gapSM = SizedBox(height: sm, width: sm);
  static const SizedBox gapMD = SizedBox(height: md, width: md);
  static const SizedBox gapLG = SizedBox(height: lg, width: lg);
  static const SizedBox gapXL = SizedBox(height: xl, width: xl);

  static const SizedBox vGapXS = SizedBox(height: xs);
  static const SizedBox vGapSM = SizedBox(height: sm);
  static const SizedBox vGapMD = SizedBox(height: md);
  static const SizedBox vGapLG = SizedBox(height: lg);
  static const SizedBox vGapXL = SizedBox(height: xl);

  static const SizedBox hGapXS = SizedBox(width: xs);
  static const SizedBox hGapSM = SizedBox(width: sm);
  static const SizedBox hGapMD = SizedBox(width: md);
  static const SizedBox hGapLG = SizedBox(width: lg);
  static const SizedBox hGapXL = SizedBox(width: xl);

  // Page padding
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: md, vertical: md);
  static const EdgeInsets horizontalPadding =
      EdgeInsets.symmetric(horizontal: md);

  // Border radius
  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;
  static const double radiusXL = 24;
  static const double radiusFull = 999;

  static const BorderRadius roundedSM =
      BorderRadius.all(Radius.circular(radiusSM));
  static const BorderRadius roundedMD =
      BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius roundedLG =
      BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius roundedXL =
      BorderRadius.all(Radius.circular(radiusXL));
  static const BorderRadius roundedFull =
      BorderRadius.all(Radius.circular(radiusFull));
}
