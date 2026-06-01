import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/theme/dot_clash_visuals.dart';
import '../../features/profile/domain/rank.dart';
import '../layout/app_spacing.dart';
import 'equipped_avatar.dart';

/// Equipped shop orb + optional level badge and rank aura (Profile hero).
class ProfileAvatarChip extends StatelessWidget {
  const ProfileAvatarChip({
    super.key,
    required this.avatarId,
    required this.displayName,
    this.initialSkinId = 'initial_skin_classic',
    this.level,
    this.size = 44,
    this.showRankAura = false,
    this.rankTier,
    this.showInitial,
    this.onTap,
  });

  final String avatarId;
  final String displayName;
  final String initialSkinId;
  final int? level;
  final double size;
  final bool showRankAura;
  final RankTier? rankTier;
  final bool? showInitial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final useInitial = showInitial ?? !_looksLikeGuestDisplayName(displayName);

    Widget avatar = EquippedAvatar(
      avatarId: avatarId,
      fallbackInitial: displayName,
      initialSkinId: initialSkinId,
      size: size,
      showInitial: useInitial,
    );

    if (level != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: _LevelBadge(level: level!, v: v, t: t),
          ),
        ],
      );
    }

    if (showRankAura && rankTier != null) {
      final auraSize = size * 2.05;
      avatar = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: 0.55,
            child: SizedBox(
              width: auraSize,
              height: auraSize,
              child: Image.asset(
                _rankAuraAsset(rankTier!),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          avatar,
        ],
      );
    }

    if (onTap == null) {
      return Semantics(label: displayName, child: avatar);
    }

    return Semantics(
      label: displayName,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppSpacing.roundedFull,
          onTap: onTap,
          child: avatar,
        ),
      ),
    );
  }

  /// Hides initials only for placeholders and long auto-generated ids (e.g. Firebase uid).
  static bool _looksLikeGuestDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'player') return true;
    if (trimmed.contains(' ')) return false;
    return trimmed.length >= 20 &&
        RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed);
  }

  static String _rankAuraAsset(RankTier tier) => switch (tier) {
        RankTier.bronze => 'assets/images/rank_aura_bronze.png',
        RankTier.silver => 'assets/images/rank_aura_silver.png',
        RankTier.gold => 'assets/images/rank_aura_gold.png',
        RankTier.platinum => 'assets/images/rank_aura_platinum.png',
        RankTier.diamond => 'assets/images/rank_aura_diamond.png',
        RankTier.master => 'assets/images/rank_aura_master.png',
      };
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.level,
    required this.v,
    required this.t,
  });

  final int level;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: v.playerA,
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(color: v.scaffold, width: 1.5),
        boxShadow: v.useGlow
            ? [
                BoxShadow(
                  color: v.playerA.withOpacity(0.35),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: Text(
        'Lv $level',
        style: t.bodySmall.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: v.onAccent,
          height: 1,
        ),
      ),
    );
  }
}
