import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../tutorial/domain/coach_tour_step.dart';
import '../../../tutorial/presentation/coach_tour_target.dart';
import '../../domain/campaign_level.dart';

/// Compact star-objective pills for in-match campaign HUD (overlays board top).
class CampaignObjectivesBar extends StatelessWidget {
  const CampaignObjectivesBar({
    super.key,
    required this.level,
    required this.humanScore,
    required this.aiScore,
    required this.humanTurnsUsed,
    required this.isOver,
    required this.humanWon,
  });

  final CampaignLevel level;
  final int humanScore;
  final int aiScore;
  final int humanTurnsUsed;
  final bool isOver;
  final bool humanWon;

  @override
  Widget build(BuildContext context) {
    final margin = humanScore - aiScore;

    final s1 = _evalObjective(level.star1, margin);
    final s2 = _evalObjective(level.star2, margin);
    final s3 = _evalObjective(level.star3, margin);

    return Row(
      children: [
        Expanded(
          child: _ObjectivePill(
            obj: level.star1,
            status: s1,
            margin: margin,
            humanTurnsUsed: humanTurnsUsed,
            aiScore: aiScore,
          ),
        ),
        AppSpacing.hGapXS,
        Expanded(
          child: CoachTourTarget(
            id: CoachTourTargetId.gameObjectivesStar2,
            child: _ObjectivePill(
              obj: level.star2,
              status: s2,
              margin: margin,
              humanTurnsUsed: humanTurnsUsed,
              aiScore: aiScore,
            ),
          ),
        ),
        AppSpacing.hGapXS,
        Expanded(
          child: _ObjectivePill(
            obj: level.star3,
            status: s3,
            margin: margin,
            humanTurnsUsed: humanTurnsUsed,
            aiScore: aiScore,
          ),
        ),
      ],
    );
  }

  _ObjStatus _evalObjective(StarObjective obj, int margin) {
    if (isOver && !humanWon) return _ObjStatus.failed;

    return switch (obj.type) {
      ObjectiveType.win =>
        isOver && humanWon ? _ObjStatus.achieved : _ObjStatus.pending,
      ObjectiveType.margin => margin >= (obj.min ?? 1)
          ? _ObjStatus.achieved
          : (isOver ? _ObjStatus.failed : _ObjStatus.pending),
      ObjectiveType.maxMoves => isOver
          ? (humanTurnsUsed <= (obj.value ?? 999)
              ? _ObjStatus.achieved
              : _ObjStatus.failed)
          : (humanTurnsUsed <= (obj.value ?? 999)
              ? _ObjStatus.pending
              : _ObjStatus.warning),
      ObjectiveType.preventChain =>
        isOver && humanWon ? _ObjStatus.achieved : _ObjStatus.pending,
      ObjectiveType.maxAiBoxes => aiScore <= (obj.value ?? 999)
          ? (isOver && humanWon ? _ObjStatus.achieved : _ObjStatus.pending)
          : (isOver ? _ObjStatus.failed : _ObjStatus.warning),
      ObjectiveType.none => _ObjStatus.achieved,
    };
  }
}

enum _ObjStatus { achieved, pending, warning, failed }

class _ObjectivePill extends StatelessWidget {
  const _ObjectivePill({
    required this.obj,
    required this.status,
    required this.margin,
    required this.humanTurnsUsed,
    required this.aiScore,
  });

  final StarObjective obj;
  final _ObjStatus status;
  final int margin;
  final int humanTurnsUsed;
  final int aiScore;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    final accent = switch (status) {
      _ObjStatus.achieved => v.gold,
      _ObjStatus.failed => v.red,
      _ObjStatus.warning => v.gold,
      _ObjStatus.pending => v.textSecondary,
    };

    final progress = _progressLabel();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: v.surface.withOpacity(0.92),
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(
          color: status == _ObjStatus.achieved
              ? v.gold.withOpacity(0.5)
              : v.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == _ObjStatus.achieved
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 14,
              color: accent,
            ),
            AppSpacing.hGapXS,
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _shortLabel(),
                    style: t.bodySmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (progress != null)
                    Text(
                      progress,
                      style: t.bodySmall.copyWith(
                        fontSize: 9,
                        color: v.textDisabled,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortLabel() => switch (obj.type) {
        ObjectiveType.win => 'Win',
        ObjectiveType.margin => '+${obj.min ?? 1} margin',
        ObjectiveType.maxMoves => '≤${obj.value ?? 0} turns',
        ObjectiveType.preventChain => 'No rival chain',
        ObjectiveType.maxAiBoxes => 'Rival ≤${obj.value ?? 0}',
        ObjectiveType.none => '',
      };

  String? _progressLabel() => switch (obj.type) {
        ObjectiveType.margin => () {
            final needed = obj.min ?? 1;
            if (margin >= needed) return '+$margin';
            return '+$margin/$needed';
          }(),
        ObjectiveType.maxMoves => '$humanTurnsUsed/${obj.value ?? 0}',
        ObjectiveType.maxAiBoxes => 'Rival $aiScore/${obj.value ?? 0}',
        _ => null,
      };
}
