import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/profile/domain/lives_logic.dart';
import '../../../../features/profile/domain/progression.dart';
import '../../../../features/profile/domain/rank.dart';
import '../../../../features/profile/domain/user_profile.dart';
import '../../../../features/tutorial/presentation/coach_tour_target.dart';
import '../../../../features/tutorial/domain/coach_tour_step.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/equipped_avatar.dart';
import 'resource_pill.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.profile,
    required this.livesSnapshot,
    required this.onOpenSettings,
    required this.onOpenShop,
    required this.onLivesTap,
  });

  final UserProfile? profile;
  final LivesSnapshot livesSnapshot;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenShop;
  final VoidCallback onLivesTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final displayName = profile?.displayName ?? 'Player';
    final avatarId = profile?.avatarId ?? 'avatar_orb_cyan';
    final rankTier = profile?.rankTier ?? RankTier.bronze;
    final rankLabel = RankSystem.label(rankTier);
    final rankColor = _rankColor(v, rankTier);
    final coins = profile?.coins ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          // ── Avatar + name + rank ─────────────────────────────────────────
          EquippedAvatar(
            avatarId: avatarId,
            fallbackInitial: displayName,
            size: 42,
            onTap: onOpenShop,
          ),
          AppSpacing.hGapSM,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: t.playerName.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 10, color: rankColor),
                  const SizedBox(width: 3),
                  Text(
                    rankLabel.toUpperCase(),
                    style: t.bodySmall.copyWith(
                      fontSize: 10,
                      color: rankColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppSpacing.hGapSM,

          // ── Resources row (lives + coins) ────────────────────────────────
          Expanded(
            child: CoachTourTarget(
              id: CoachTourTargetId.homeTopBarLives,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ResourcePill(
                      icon: Icons.bolt_rounded,
                      label: _livesLabel(livesSnapshot),
                      iconColor: livesSnapshot.isFull ? v.green : v.gold,
                      onTap: onLivesTap,
                    ),
                    AppSpacing.hGapXS,
                    ResourcePill(
                      icon: Icons.monetization_on_rounded,
                      label: '$coins',
                      iconColor: v.gold,
                      trailing: Icon(
                        Icons.add_circle_rounded,
                        size: 14,
                        color: v.gold,
                      ),
                      onTap: onOpenShop,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Action icons ─────────────────────────────────────────────────
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined, color: v.textSecondary, size: 24),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }

  static Color _rankColor(DotClashVisuals v, RankTier tier) => switch (tier) {
        RankTier.bronze => const Color(0xFFCD7F32),
        RankTier.silver => const Color(0xFFC0C0C0),
        RankTier.gold => v.gold,
        RankTier.platinum => const Color(0xFF00D4FF),
        RankTier.diamond => const Color(0xFF9D4DFF),
        RankTier.master => const Color(0xFFFF4C4C),
      };

  static String _livesLabel(LivesSnapshot snapshot) {
    if (snapshot.isFull) return '${Progression.maxLives}/${Progression.maxLives} Full';
    final timer = snapshot.timeUntilNextLife ?? Duration.zero;
    final mm = timer.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = timer.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${snapshot.effectiveLives}/${Progression.maxLives} $mm:$ss';
  }
}
