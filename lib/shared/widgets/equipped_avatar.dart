import 'package:flutter/material.dart';

import '../../core/theme/dot_clash_visuals.dart';
import '../layout/app_spacing.dart';
import 'initial_skin_style.dart';

/// Fixed shop-orb colors so equipped avatars look the same on every board theme.
abstract final class AvatarOrbColors {
  static const cyan = Color(0xFF00D4FF);
  static const magenta = Color(0xFFFF2EFF);
  static const gold = Color(0xFFFFB830);
  static const lime = Color(0xFFA8FF30);
  static const coral = Color(0xFFFF6B4A);
  static const violet = Color(0xFFB44DFF);
  static const ice = Color(0xFF9CE8FF);
  static const rose = Color(0xFFFF5C9A);
}

class EquippedAvatar extends StatelessWidget {
  const EquippedAvatar({
    super.key,
    required this.avatarId,
    required this.fallbackInitial,
    this.initialSkinId = 'initial_skin_classic',
    this.size = 40,
    this.showInitial = true,
    this.onTap,
  });

  final String avatarId;
  final String fallbackInitial;
  final String initialSkinId;
  final double size;

  /// When true and the name is displayable, shows an initial over the orb.
  final bool showInitial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final accent = accentForAvatarId(avatarId, v);
    final initial = _initialLetter(fallbackInitial);
    final showLetter = showInitial && initial.isNotEmpty;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.6),
        boxShadow: v.useGlow
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _NeonOrbCore(accent: accent, diameter: size * 0.72),
          if (showLetter)
            Text(
              initial,
              style: InitialSkinStyles.letterStyle(
                skinId: initialSkinId,
                fontSize: size * 0.38,
                accent: accent,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return avatar;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppSpacing.roundedFull,
        onTap: onTap,
        child: avatar,
      ),
    );
  }

  static Color accentForAvatarId(String avatarId, DotClashVisuals v) {
    switch (avatarId) {
      case 'avatar_orb_magenta':
        return AvatarOrbColors.magenta;
      case 'avatar_orb_gold':
        return AvatarOrbColors.gold;
      case 'avatar_orb_lime':
        return AvatarOrbColors.lime;
      case 'avatar_orb_coral':
        return AvatarOrbColors.coral;
      case 'avatar_orb_violet':
        return AvatarOrbColors.violet;
      case 'avatar_orb_ice':
        return AvatarOrbColors.ice;
      case 'avatar_orb_rose':
        return AvatarOrbColors.rose;
      case 'avatar_orb_cyan':
      default:
        return AvatarOrbColors.cyan;
    }
  }

  static String _initialLetter(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase();
  }
}

/// Glowing sphere used for equipped shop orbs (cyan / magenta / gold).
class _NeonOrbCore extends StatelessWidget {
  const _NeonOrbCore({
    required this.accent,
    required this.diameter,
  });

  final Color accent;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.28, -0.32),
          radius: 0.95,
          colors: [
            Colors.white,
            Color.lerp(Colors.white, accent, 0.35)!,
            accent,
            accent.withValues(alpha: 0.45),
          ],
          stops: const [0.0, 0.18, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.7),
            blurRadius: diameter * 0.45,
            spreadRadius: diameter * 0.06,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: diameter * 0.9,
            spreadRadius: diameter * 0.12,
          ),
        ],
      ),
    );
  }
}
