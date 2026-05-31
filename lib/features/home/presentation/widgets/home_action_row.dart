import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../features/tutorial/presentation/coach_tour_target.dart';
import '../../../../features/tutorial/domain/coach_tour_step.dart';
import '../../../profile/providers/profile_providers.dart';

/// Three equal-width action cards: Quick Match · Daily Puzzle (featured) · Local Play.
class HomeActionRow extends ConsumerWidget {
  const HomeActionRow({
    super.key,
    required this.onAiTap,
    required this.onLocalTap,
  });

  final VoidCallback onAiTap;
  final VoidCallback onLocalTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final profile = ref.watch(profileProvider).valueOrNull;
    final puzzleCompleted = profile?.isDailyPuzzleCompletedToday ?? false;
    final streak = profile?.dailyPuzzleStreak ?? 0;

    return SizedBox(
      height: 152,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CoachTourTarget(
              id: CoachTourTargetId.homeQuickMatch,
              child: _ActionCard(
                title: 'QUICK MATCH',
                subtitle: 'Play anytime',
                icon: Icons.sports_esports_outlined,
                color: v.playerA,
                backgroundImage: 'assets/images/card_vs_ai.png',
                onTap: onAiTap,
                v: v,
                t: context.txt,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: CoachTourTarget(
              id: CoachTourTargetId.homeDailyPuzzle,
              child: _DailyPuzzleCard(
                completed: puzzleCompleted,
                streak: streak,
                onTap: puzzleCompleted
                    ? null
                    : () => context.push(AppRoutes.dailyPuzzle),
                v: v,
                t: context.txt,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: CoachTourTarget(
              id: CoachTourTargetId.homeLocal,
              child: _ActionCard(
                title: 'LOCAL',
                subtitle: 'Pass & play\non this device',
                icon: Icons.people_outline_rounded,
                color: v.playerB,
                backgroundImage: 'assets/images/card_local_play.png',
                onTap: onLocalTap,
                v: v,
                t: context.txt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Standard action card ──────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.v,
    required this.t,
    this.backgroundImage,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final DotClashVisuals v;
  final AppTextStyles t;
  final String? backgroundImage;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.roundedLG,
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: v.useGlow
              ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 14)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.roundedLG,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              if (backgroundImage != null)
                Image.asset(
                  backgroundImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),

              // Dark gradient overlay for readability
              if (backgroundImage != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Color.lerp(Colors.black, color, 0.2)!.withOpacity(0.75),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

              // Solid background fallback when no card image
              if (backgroundImage == null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [v.surface, Color.lerp(v.surface, color, 0.07)!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.5)),
                      ),
                      child: Icon(icon, color: color, size: 23),
                    ),
                    AppSpacing.vGapXS,
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: t.playerName.copyWith(
                          color: color,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                    AppSpacing.vGapXS,
                    Text(
                      subtitle,
                      style: t.bodySmall.copyWith(
                        fontSize: 11,
                        color: backgroundImage != null
                            ? Colors.white70
                            : null,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Featured Daily Puzzle card ────────────────────────────────────────────────

class _DailyPuzzleCard extends StatelessWidget {
  const _DailyPuzzleCard({
    required this.completed,
    required this.streak,
    required this.onTap,
    required this.v,
    required this.t,
  });

  final bool completed;
  final int streak;
  final VoidCallback? onTap;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    final featureColor = v.playerB;
    final timeUntilMidnight = _timeUntilMidnight();
    final timerLabel = completed
        ? _formatDuration(timeUntilMidnight)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.roundedLG,
          border: Border.all(
            color: featureColor.withOpacity(completed ? 0.3 : 0.65),
            width: completed ? 1 : 1.5,
          ),
          boxShadow: v.useGlow && !completed
              ? [BoxShadow(color: featureColor.withOpacity(0.18), blurRadius: 16)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.roundedLG,
          child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.asset(
              'assets/images/card_daily_puzzle.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Color.lerp(Colors.black, featureColor, 0.25)!.withOpacity(0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Streak badge
            if (streak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: v.gold.withOpacity(0.15),
                  borderRadius: AppSpacing.roundedFull,
                  border: Border.all(color: v.gold.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 11, color: v.gold),
                    const SizedBox(width: 3),
                    Text(
                      '$streak',
                      style: t.bodySmall.copyWith(
                        color: v.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: featureColor.withOpacity(completed ? 0.08 : 0.15),
                shape: BoxShape.circle,
                border:
                    Border.all(color: featureColor.withOpacity(completed ? 0.2 : 0.45)),
              ),
              child: Icon(
                completed ? Icons.check_circle_outline_rounded : Icons.extension_rounded,
                color: completed ? v.green : featureColor,
                size: 25,
              ),
            ),
            AppSpacing.vGapSM,

            Text(
              'DAILY PUZZLE',
              style: t.playerName.copyWith(
                color: completed ? v.textSecondary : featureColor,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapXS,

            if (completed && timerLabel != null)
              Text(
                'New in $timerLabel',
                style: t.bodySmall.copyWith(
                  fontSize: 10,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              )
            else
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: featureColor,
                  borderRadius: AppSpacing.roundedFull,
                ),
                child: Text(
                  'PLAY NOW',
                  style: t.bodySmall.copyWith(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Duration _timeUntilMidnight() {
    final now = DateTime.now().toUtc();
    final midnight = DateTime.utc(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
