import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/home/domain/home_ui_models.dart';
import '../../../../shared/layout/app_spacing.dart';

class DailyMissionsSection extends StatelessWidget {
  const DailyMissionsSection({
    super.key,
    required this.missions,
    this.onClaim,
  });

  final List<DailyMission> missions;
  final void Function(String missionId)? onClaim;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    final resetIn = _formatResetTimer();
    final completedCount =
        missions.where((m) => m.claimed || m.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────────────
        Row(
          children: [
            Text(
              'DAILY MISSIONS',
              style: t.scoreLabel,
            ),
            AppSpacing.hGapSM,
            // Completion chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: completedCount == missions.length
                    ? v.green.withOpacity(0.15)
                    : v.playerA.withOpacity(0.12),
                borderRadius: AppSpacing.roundedFull,
                border: Border.all(
                  color: completedCount == missions.length
                      ? v.green.withOpacity(0.5)
                      : v.playerA.withOpacity(0.3),
                ),
              ),
              child: Text(
                '$completedCount/${missions.length}',
                style: t.bodySmall.copyWith(
                  fontSize: 10,
                  color:
                      completedCount == missions.length ? v.green : v.playerA,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 11, color: v.textSecondary),
                const SizedBox(width: 3),
                Text(
                  'Resets in $resetIn',
                  style: t.bodySmall.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        AppSpacing.vGapSM,

        // ── Mission square cards ─────────────────────────────────────────────
        SizedBox(
          height: 115,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < missions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MissionSquareCard(
                    mission: missions[i],
                    onClaim: onClaim,
                    v: v,
                    t: t,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _formatResetTimer() {
    final now = DateTime.now().toUtc();
    final midnight = DateTime.utc(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

/// Square mission card used in the 3-column grid.
class _MissionSquareCard extends StatelessWidget {
  const _MissionSquareCard({
    required this.mission,
    required this.onClaim,
    required this.v,
    required this.t,
  });

  final DailyMission mission;
  final void Function(String)? onClaim;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    final isDone = mission.claimed || mission.completed;
    final barColor = isDone ? v.green : v.playerA;
    final iconColor = isDone ? v.green : v.playerA;
    final iconData = _iconFor(mission.id);

    final bgImage = _imageFor(mission.id);
    final showBg = bgImage != null;

    return GestureDetector(
      onTap: mission.readyToClaim && onClaim != null
          ? () => onClaim!(mission.id)
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.roundedLG,
          border: Border.all(
            color:
                mission.readyToClaim ? v.green.withOpacity(0.5) : v.cardBorder,
            width: mission.readyToClaim ? 1.5 : 1.0,
          ),
          boxShadow: v.useGlow && mission.readyToClaim
              ? [BoxShadow(color: v.green.withOpacity(0.12), blurRadius: 10)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.roundedLG,
          child: Container(
            color: v.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background art
                if (showBg)
                  Image.asset(
                    bgImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                if (showBg)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                if (!showBg) ColoredBox(color: v.surface),

                // Content
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      ClipOval(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: showBg
                              ? Image.asset(
                                  bgImage!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: iconColor.withOpacity(0.12),
                                    child: Icon(iconData,
                                        size: 16, color: iconColor),
                                  ),
                                )
                              : Container(
                                  color: iconColor.withOpacity(0.12),
                                  child: Icon(iconData,
                                      size: 16, color: iconColor),
                                ),
                        ),
                      ),

                      // Mission title
                      Text(
                        mission.title,
                        style: t.playerName.copyWith(fontSize: 11),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Progress bar
                      ClipRRect(
                        borderRadius: AppSpacing.roundedFull,
                        child: LinearProgressIndicator(
                          value: mission.fraction,
                          minHeight: 5,
                          backgroundColor: v.cardBorder.withOpacity(0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),

                      // Progress count + reward
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${mission.progress}/${mission.target}',
                            style: t.bodySmall.copyWith(fontSize: 10),
                          ),
                          if (mission.claimed)
                            Icon(Icons.check_circle_rounded,
                                size: 13, color: v.green)
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.monetization_on_rounded,
                                    size: 10, color: v.gold),
                                const SizedBox(width: 2),
                                Text(
                                  '+${mission.rewardCoins}',
                                  style: t.bodySmall.copyWith(
                                    color: v.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String id) => switch (id) {
        'win_matches' => Icons.emoji_events_rounded,
        'play_games' => Icons.videogame_asset_rounded,
        'capture_boxes' => Icons.grid_on_rounded,
        _ => Icons.task_alt_rounded,
      };

  static String? _imageFor(String id) => switch (id) {
        'win_matches' => 'assets/images/mission_win_matches.png',
        'play_games' => 'assets/images/mission_play_games.png',
        'capture_boxes' => 'assets/images/mission_capture_boxes.png',
        _ => null,
      };
}
