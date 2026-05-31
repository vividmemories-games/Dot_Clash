import 'package:flutter/material.dart';

import '../../core/theme/dot_clash_visuals.dart';
import '../layout/app_spacing.dart';

class EquippedAvatar extends StatelessWidget {
  const EquippedAvatar({
    super.key,
    required this.avatarId,
    required this.fallbackInitial,
    this.size = 40,
    this.onTap,
  });

  final String avatarId;
  final String fallbackInitial;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final accent = _accentForAvatar(avatarId, v);

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withOpacity(0.14),
        border: Border.all(color: accent.withOpacity(0.5), width: 1.4),
        boxShadow: v.useGlow
            ? [
                BoxShadow(
                  color: accent.withOpacity(0.28),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          fallbackInitial.trim().isEmpty
              ? 'P'
              : fallbackInitial.trim()[0].toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
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

  static Color _accentForAvatar(String avatarId, DotClashVisuals v) {
    switch (avatarId) {
      case 'avatar_orb_magenta':
        return v.playerB;
      case 'avatar_orb_gold':
        return v.gold;
      case 'avatar_orb_cyan':
      default:
        return v.playerA;
    }
  }
}
