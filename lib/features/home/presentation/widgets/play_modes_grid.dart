import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/tutorial/domain/coach_tour_step.dart';
import '../../../../features/tutorial/presentation/coach_tour_target.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../profile/providers/profile_providers.dart';

/// 2×2 play mode grid: Quick Match | Challenge / Daily Puzzle | Local.
class PlayModesGrid extends ConsumerWidget {
  const PlayModesGrid({
    super.key,
    required this.onAiTap,
    required this.onLocalTap,
  });

  final VoidCallback onAiTap;
  final VoidCallback onLocalTap;

  static const _cellHeight = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final profile = ref.watch(profileProvider).valueOrNull;
    final puzzleCompleted = profile?.isDailyPuzzleCompletedToday ?? false;
    final streak = profile?.dailyPuzzleStreak ?? 0;

    Widget row(List<Widget> cells) {
      return SizedBox(
        height: _cellHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cells[0]),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: cells[1]),
          ],
        ),
      );
    }

    return Column(
      children: [
        row([
          CoachTourTarget(
            id: CoachTourTargetId.homeQuickMatch,
            child: _ActionCard(
              title: 'QUICK MATCH',
              subtitle: 'Play anytime',
              icon: Icons.sports_esports_outlined,
              color: v.playerA,
              backgroundImage: 'assets/images/card_vs_ai.png',
              onTap: onAiTap,
              v: v,
              t: t,
            ),
          ),
          CoachTourTarget(
            id: CoachTourTargetId.homeChallenge,
            child: _ActionCard(
              title: 'CHALLENGE',
              subtitle: 'Live 6×6 online',
              icon: Icons.groups_rounded,
              color: v.gold,
              backgroundImage: 'assets/images/card_challenge.png',
              onTap: () => context.push(AppRoutes.challengeHome),
              v: v,
              t: t,
            ),
          ),
        ]),
        AppSpacing.vGapSM,
        row([
          CoachTourTarget(
            id: CoachTourTargetId.homeDailyPuzzle,
            child: _DailyPuzzleCard(
              completed: puzzleCompleted,
              streak: streak,
              onTap: puzzleCompleted
                  ? null
                  : () => context.push(AppRoutes.dailyPuzzle),
              v: v,
              t: t,
            ),
          ),
          CoachTourTarget(
            id: CoachTourTargetId.homeLocal,
            child: _ActionCard(
              title: 'LOCAL',
              subtitle: 'Pass & play\non this device',
              icon: Icons.people_outline_rounded,
              color: v.playerB,
              backgroundImage: 'assets/images/card_local_play.png',
              onTap: onLocalTap,
              v: v,
              t: t,
            ),
          ),
        ]),
      ],
    );
  }
}

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
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: v.useGlow
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 14)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.roundedLG,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backgroundImage != null)
                Image.asset(
                  backgroundImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              if (backgroundImage != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Color.lerp(Colors.black, color, 0.2)!
                            .withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
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
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(icon, color: color, size: 21),
                    ),
                    AppSpacing.vGapXS,
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: t.playerName.copyWith(
                          color: color,
                          fontSize: 11,
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
                        fontSize: 10,
                        color: backgroundImage != null ? Colors.white70 : null,
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

class _DailyPuzzleCard extends StatefulWidget {
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
  State<_DailyPuzzleCard> createState() => _DailyPuzzleCardState();
}

class _DailyPuzzleCardState extends State<_DailyPuzzleCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.completed) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant _DailyPuzzleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && _timer == null) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!widget.completed) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final t = widget.t;
    final completed = widget.completed;
    final featureColor = v.playerB;
    final countdown = completed ? _formatCountdown(_timeUntilMidnight()) : null;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(
          color: featureColor.withValues(alpha: completed ? 0.25 : 0.4),
        ),
        boxShadow: v.useGlow && !completed
            ? [
                BoxShadow(
                  color: featureColor.withValues(alpha: 0.12),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.roundedLG,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/card_daily_puzzle.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: completed ? 0.72 : 0.5),
                    Color.lerp(Colors.black, featureColor, 0.25)!
                        .withValues(alpha: completed ? 0.88 : 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: v.gold.withValues(alpha: 0.15),
                        borderRadius: AppSpacing.roundedFull,
                        border: Border.all(color: v.gold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 11,
                            color: v.gold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.streak}',
                            style: t.bodySmall.copyWith(
                              color: v.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: featureColor.withValues(
                        alpha: completed ? 0.08 : 0.15,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: featureColor.withValues(
                          alpha: completed ? 0.2 : 0.45,
                        ),
                      ),
                    ),
                    child: Icon(
                      completed
                          ? Icons.check_circle_outline_rounded
                          : Icons.extension_rounded,
                      color: completed ? v.green : featureColor,
                      size: 21,
                    ),
                  ),
                  AppSpacing.vGapXS,
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
                  Text(
                    completed
                        ? 'Next puzzle in $countdown'
                        : "Beat today's board",
                    style: t.bodySmall.copyWith(
                      fontSize: 10,
                      color: Colors.white70,
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
    );

    if (completed) {
      return IgnorePointer(child: card);
    }

    return GestureDetector(onTap: widget.onTap, child: card);
  }

  static Duration _timeUntilMidnight() {
    final now = DateTime.now().toUtc();
    final midnight = DateTime.utc(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  static String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '<1m';
  }
}
