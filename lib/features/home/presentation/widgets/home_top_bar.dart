import 'package:flutter/material.dart';

import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/profile/domain/lives_logic.dart';
import '../../../../features/profile/domain/progression.dart';
import '../../../../features/profile/domain/user_profile.dart';
import '../../../../features/tutorial/presentation/coach_tour_target.dart';
import '../../../../features/tutorial/domain/coach_tour_step.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/profile_avatar_chip.dart';
import 'resource_pill.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.profile,
    required this.livesSnapshot,
    required this.onOpenSettings,
    required this.onOpenShop,
    required this.onOpenProfile,
    required this.onLivesTap,
  });

  final UserProfile? profile;
  final LivesSnapshot livesSnapshot;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenProfile;
  final VoidCallback onLivesTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final displayName = profile?.displayName ?? 'Player';
    final avatarId = profile?.avatarId ?? 'avatar_orb_cyan';
    final initialSkinId = profile?.initialSkinId ?? 'initial_skin_classic';
    final level = profile?.campaignPlayerLevel ?? 1;
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
          ProfileAvatarChip(
            avatarId: avatarId,
            displayName: displayName,
            initialSkinId: initialSkinId,
            level: level,
            size: 44,
            onTap: onOpenProfile,
          ),
          AppSpacing.hGapSM,

          Expanded(
            child: CoachTourTarget(
              id: CoachTourTargetId.homeTopBarLives,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: ResourcePill(
                      icon: Icons.bolt_rounded,
                      label: _livesLabel(livesSnapshot),
                      iconColor: livesSnapshot.isFull ? v.green : v.gold,
                      onTap: onLivesTap,
                    ),
                  ),
                  AppSpacing.hGapXS,
                  Flexible(
                    child: ResourcePill(
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
                  ),
                ],
              ),
            ),
          ),

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

  static String _livesLabel(LivesSnapshot snapshot) {
    if (snapshot.isFull) {
      return '${Progression.maxLives}/${Progression.maxLives} Full';
    }
    final timer = snapshot.timeUntilNextLife ?? Duration.zero;
    final mm = timer.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = timer.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${snapshot.effectiveLives}/${Progression.maxLives} $mm:$ss';
  }
}
