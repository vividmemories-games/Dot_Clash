import 'package:flutter/material.dart';

import 'dot_clash_visuals.dart';

/// Themed text styles for Dot Clash neon palettes.
@immutable
class AppTextStyles {
  const AppTextStyles._({
    required this.heroTitle,
    required this.gameTitle,
    required this.scoreNumber,
    required this.scoreLabel,
    required this.playerName,
    required this.tag,
    required this.body,
    required this.bodySmall,
    required this.buttonLabel,
    required this.turnLabel,
    required this.turnPlayer,
    required this.timerText,
    required this.vs,
  });

  factory AppTextStyles.of(BuildContext context) {
    return AppTextStyles._neon(context.dc);
  }

  final TextStyle heroTitle;
  final TextStyle gameTitle;
  final TextStyle scoreNumber;
  final TextStyle scoreLabel;
  final TextStyle playerName;
  final TextStyle tag;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle buttonLabel;
  final TextStyle turnLabel;
  final TextStyle turnPlayer;
  final TextStyle timerText;
  final TextStyle vs;

  factory AppTextStyles._neon(DotClashVisuals v) {
    return AppTextStyles._(
      heroTitle: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
        color: v.textPrimary,
        height: 1.0,
      ),
      gameTitle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
        color: v.textPrimary,
        height: 1.0,
      ),
      scoreNumber: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        color: v.textPrimary,
        height: 1.0,
      ),
      scoreLabel: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: v.textSecondary,
        height: 1.2,
      ),
      playerName: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: v.textPrimary,
        height: 1.2,
      ),
      tag: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: v.textSecondary,
        height: 1.2,
      ),
      body: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: v.textPrimary,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: v.textSecondary,
        height: 1.4,
      ),
      buttonLabel: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: v.textPrimary,
        height: 1.2,
      ),
      turnLabel: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: v.textSecondary,
        height: 1.2,
      ),
      turnPlayer: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: v.textPrimary,
        height: 1.2,
      ),
      timerText: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: v.textSecondary,
        height: 1.2,
      ),
      vs: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: v.vsText,
        height: 1.0,
      ),
    );
  }
}

extension AppTextStylesX on BuildContext {
  AppTextStyles get txt => AppTextStyles.of(this);
}
