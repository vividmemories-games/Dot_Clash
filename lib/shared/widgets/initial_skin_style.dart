import 'package:flutter/material.dart';

/// Typography styles for avatar initials (shop + profile).
abstract final class InitialSkinStyles {
  static TextStyle letterStyle({
    required String skinId,
    required double fontSize,
    required Color accent,
  }) {
    switch (skinId) {
      case 'initial_skin_glow':
        return _base(fontSize).copyWith(
          color: Colors.white,
          shadows: [
            Shadow(color: accent.withOpacity(0.95), blurRadius: 14),
            Shadow(color: accent.withOpacity(0.55), blurRadius: 22),
          ],
        );
      case 'initial_skin_ultra':
        return _base(fontSize).copyWith(
          color: const Color(0xFFFFF4C2),
          shadows: [
            Shadow(color: accent.withOpacity(0.9), blurRadius: 10),
            const Shadow(color: Color(0xFFFFE082), blurRadius: 6),
          ],
        );
      case 'initial_skin_neon':
        return _base(fontSize).copyWith(
          color: const Color(0xFFE8FFFF),
          shadows: [
            const Shadow(color: Color(0xFF00D4FF), blurRadius: 12),
            const Shadow(color: Color(0xFFFF2EFF), blurRadius: 12),
          ],
        );
      case 'initial_skin_outline':
        // Stroke via [foreground] only — cannot set [color] on the same TextStyle.
        return TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.09
            ..color = Colors.white,
          shadows: [
            Shadow(color: accent.withValues(alpha: 0.75), blurRadius: 8),
          ],
        );
      case 'initial_skin_shadow':
        return _base(fontSize).copyWith(
          color: Colors.white.withOpacity(0.92),
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.85),
              blurRadius: 0,
              offset: Offset(fontSize * 0.06, fontSize * 0.08),
            ),
            Shadow(color: accent.withOpacity(0.35), blurRadius: 6),
          ],
        );
      case 'initial_skin_chrome':
        return _base(fontSize).copyWith(
          color: const Color(0xFFE8ECF5),
          shadows: const [
            Shadow(
                color: Color(0xFF9AA8C4), blurRadius: 1, offset: Offset(0, 1)),
            Shadow(
                color: Color(0xFFFFFFFF),
                blurRadius: 0,
                offset: Offset(0, -0.5)),
          ],
        );
      case 'initial_skin_arcade':
        return TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -0.5,
          color: const Color(0xFFB8FF30),
          shadows: [
            Shadow(
                color: Colors.black.withOpacity(0.9),
                blurRadius: 0,
                offset: Offset(2, 2)),
            const Shadow(color: Color(0xFF00D4FF), blurRadius: 8),
          ],
        );
      case 'initial_skin_classic':
      default:
        return _base(fontSize).copyWith(
          color: Colors.white,
          shadows: [
            Shadow(color: accent.withOpacity(0.9), blurRadius: 8),
          ],
        );
    }
  }

  static TextStyle _base(double fontSize) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1,
      );
}
