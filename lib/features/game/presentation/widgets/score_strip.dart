import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../tutorial/domain/coach_tour_step.dart';
import '../../../tutorial/presentation/coach_tour_target.dart';
import '../../domain/models/game_state.dart';

/// Match turn bar: avatars, center score ratio, turn pills (fixed height).
class ScoreStrip extends StatelessWidget {
  const ScoreStrip({
    super.key,
    required this.state,
    this.playerALabel = 'Player A',
    this.playerBLabel = 'Player B',
    this.playerAInitial,
    this.playerBInitial,
    this.opponentIsBoss = false,
    this.bossAccentColor,
    this.secondsLeft,
    this.showTimer = false,
    this.isLocalMode = false,
    /// When set (challenge / online), turn pills are relative to this player id.
    this.localPlayerId,
  });

  final GameState state;
  final String playerALabel;
  final String playerBLabel;
  final String? playerAInitial;
  final String? playerBInitial;
  final bool opponentIsBoss;
  final Color? bossAccentColor;
  final int? secondsLeft;
  final bool showTimer;
  final bool isLocalMode;
  final String? localPlayerId;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final ids = state.playerIds;
    final isATurn = state.currentPlayerId == ids[0];
    final isBTurn = state.currentPlayerId == ids[1];
    final bColor = opponentIsBoss ? (bossAccentColor ?? v.red) : v.playerB;
    final scoreA = state.scoreOf(ids[0]);
    final scoreB = state.scoreOf(ids[1]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: v.surface,
          borderRadius: AppSpacing.roundedLG,
          border: Border.all(color: v.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: _PlayerColumn(
                  label: playerALabel,
                  initial: playerAInitial ?? ids[0],
                  color: v.playerA,
                  isActive: isATurn,
                  alignEnd: false,
                  turnPillLabel: _turnPillLabel(
                    isActiveSide: isATurn,
                    columnPlayerId: ids[0],
                    v: v,
                    isLeft: true,
                  ),
                ),
              ),
              _ScoreCenter(
                scoreA: scoreA,
                scoreB: scoreB,
                colorA: v.playerA,
                colorB: bColor,
                showTimer: showTimer && !state.isOver,
                secondsLeft: secondsLeft ?? 0,
              ),
              Expanded(
                child: _PlayerColumn(
                  label: playerBLabel,
                  initial: playerBInitial ?? ids[1],
                  color: bColor,
                  isActive: !isATurn,
                  alignEnd: true,
                  isBoss: opponentIsBoss,
                  turnPillLabel: _turnPillLabel(
                    isActiveSide: isBTurn,
                    columnPlayerId: ids[1],
                    v: v,
                    isLeft: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _turnPillLabel({
    required bool isActiveSide,
    required String columnPlayerId,
    required DotClashVisuals v,
    required bool isLeft,
  }) {
    if (isLocalMode) {
      if (isLeft) {
        return isActiveSide ? ('YOUR TURN') : ('WAITING');
      }
      return isActiveSide ? ('P2 TURN') : ('WAITING');
    }
    if (localPlayerId != null) {
      final isMe = columnPlayerId == localPlayerId;
      if (isActiveSide) {
        return isMe ? 'YOUR TURN' : 'THEIR TURN';
      }
      return 'WAITING';
    }
    if (isLeft) {
      return isActiveSide ? ('YOUR TURN') : ('WAITING');
    }
    return isActiveSide ? ('THEIR TURN') : ('WAITING');
  }
}

class _PlayerColumn extends StatelessWidget {
  const _PlayerColumn({
    required this.label,
    required this.initial,
    required this.color,
    required this.isActive,
    required this.alignEnd,
    required this.turnPillLabel,
    this.isBoss = false,
  });

  final String label;
  final String initial;
  final Color color;
  final bool isActive;
  final bool alignEnd;
  final bool isBoss;
  final String turnPillLabel;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!alignEnd) ...[
              _Avatar(
                  initial: initial,
                  color: color,
                  isActive: isActive,
                  isBoss: isBoss),
              AppSpacing.hGapSM,
            ],
            Flexible(
              child: Text(
                label,
                style: t.scoreLabel.copyWith(
                  color: isActive ? color : v.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (alignEnd) ...[
              AppSpacing.hGapSM,
              _Avatar(
                  initial: initial,
                  color: color,
                  isActive: isActive,
                  isBoss: isBoss),
            ],
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 22,
          child: Align(
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: _TurnPill(
              label: turnPillLabel,
              color: color,
              isActive: isActive,
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initial,
    required this.color,
    required this.isActive,
    this.isBoss = false,
  });

  final String initial;
  final Color color;
  final bool isActive;
  final bool isBoss;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(isActive ? 0.14 : 0.08),
            border: Border.all(color: color, width: isActive ? 2.5 : 1.5),
            boxShadow: isActive && v.useGlow
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.45),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isActive ? color : color.withOpacity(0.55),
            ),
          ),
        ),
        if (isBoss)
          Positioned(
            top: -4,
            right: -3,
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 14,
              color: color,
            ),
          ),
      ],
    );
  }
}

class _TurnPill extends StatelessWidget {
  const _TurnPill({
    required this.label,
    required this.color,
    required this.isActive,
  });

  final String label;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final pillColor = isActive ? color : v.textSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pillColor.withOpacity(isActive ? 0.14 : 0.06),
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(
          color: pillColor.withOpacity(isActive ? 0.45 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? pillColor : pillColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: pillColor.withOpacity(isActive ? 1 : 0.65),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCenter extends StatelessWidget {
  const _ScoreCenter({
    required this.scoreA,
    required this.scoreB,
    required this.colorA,
    required this.colorB,
    required this.showTimer,
    required this.secondsLeft,
  });

  final int scoreA;
  final int scoreB;
  final Color colorA;
  final Color colorB;
  final bool showTimer;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final isLowTime = secondsLeft <= 10;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: Row(
              key: ValueKey('$scoreA-$scoreB'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$scoreA',
                  style: t.scoreNumber.copyWith(
                    fontSize: 28,
                    color: colorA,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ':',
                    style: t.scoreNumber.copyWith(
                      fontSize: 22,
                      color: v.textSecondary,
                      height: 1,
                    ),
                  ),
                ),
                Text(
                  '$scoreB',
                  style: t.scoreNumber.copyWith(
                    fontSize: 28,
                    color: colorB,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (showTimer) ...[
            const SizedBox(height: 6),
            CoachTourTarget(
              id: CoachTourTargetId.gameTurnTimer,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: v.surfaceElevated,
                  borderRadius: AppSpacing.roundedFull,
                  border: Border.all(
                    color: isLowTime
                        ? v.red.withOpacity(0.55)
                        : v.playerA.withOpacity(0.35),
                    width: isLowTime ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: isLowTime ? v.red : v.playerA,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${secondsLeft.toString().padLeft(2, '0')}s',
                      style: t.timerText.copyWith(
                        fontSize: 18,
                        color: isLowTime ? v.red : v.textPrimary,
                        fontWeight:
                            isLowTime ? FontWeight.w900 : FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
