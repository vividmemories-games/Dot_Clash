import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dot_clash_visuals.dart';

/// Dot Clash neon arena themes backed by [DotClashVisuals].
abstract final class AppTheme {
  static ThemeData neon() => _buildFor(DotClashVisuals.neon);
  static ThemeData fromVisuals(DotClashVisuals visuals) => _buildFor(visuals);

  static ThemeData _buildFor(DotClashVisuals v) {
    const brightness = Brightness.dark;

    final colorScheme = ColorScheme.dark(
      primary: v.playerA,
      secondary: v.playerB,
      surface: v.surface,
      onPrimary: v.onAccent,
      onSecondary: v.onAccent,
      onSurface: v.textPrimary,
      error: v.red,
    );

    final statusBarOverlay = SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    final textTheme = ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: v.textPrimary,
          displayColor: v.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: v.scaffold,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [v],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: statusBarOverlay,
        titleTextStyle: const TextStyle().copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: v.textPrimary,
        ),
        iconTheme: IconThemeData(color: v.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: v.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: v.cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: v.playerA,
          foregroundColor: v.onAccent,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: v.playerA,
          side: BorderSide(color: v.playerA, width: 1.5),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: v.playerA,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: v.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: v.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: v.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: v.playerA, width: 1.5),
        ),
        labelStyle: TextStyle(color: v.textSecondary),
        hintStyle: TextStyle(color: v.textDisabled),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: v.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: v.cardBorder),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: v.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: v.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: v.surfaceElevated,
        contentTextStyle: TextStyle(
          color: v.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: v.playerA.withValues(alpha: 0.85), width: 2),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
      dividerTheme: DividerThemeData(
        color: v.cardBorder,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
