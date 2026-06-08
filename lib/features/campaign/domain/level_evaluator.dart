import '../../game/domain/models/game_state.dart';
import 'campaign_level.dart';
import 'campaign_move_metrics.dart';

/// Post-game result payload used to evaluate objectives and award stars.
class MatchPayload {
  const MatchPayload({
    required this.finalState,
    required this.humanPlayerId,
  });

  final GameState finalState;
  final String humanPlayerId;

  bool get humanWon =>
      finalState.winnerId == humanPlayerId && finalState.isOver;
  bool get isTie => finalState.isTie;

  int get humanScore => finalState.scoreOf(humanPlayerId);
  int get aiScore {
    final aiId = finalState.playerIds.firstWhere(
      (id) => id != humanPlayerId,
      orElse: () => 'B',
    );
    return finalState.scoreOf(aiId);
  }

  int get margin => humanScore - aiScore;

  /// Human turns taken (chains = 1 turn, not many lines).
  int get humanTurnCount =>
      CampaignMoveMetrics.humanTurnCount(finalState, humanPlayerId);

  /// Maximum boxes the AI captured in any single AI control period.
  int get aiMaxChainBoxes =>
      CampaignMoveMetrics.aiMaxChainBoxes(finalState, humanPlayerId);

  /// Total boxes claimed by the AI.
  int get aiBoxCount =>
      CampaignMoveMetrics.aiBoxCount(finalState, humanPlayerId);
}

/// Evaluates the 3-star conditions for a campaign level.
abstract final class LevelEvaluator {
  /// Returns stars earned (0–3) for this match.
  static int evaluate(CampaignLevel level, MatchPayload payload) {
    if (!payload.humanWon) return 0;

    final s1 = _check(level.star1, payload);
    if (!s1) return 1;
    final s2 = _check(level.star2, payload);
    if (!s2) return 1;
    final s3 = _check(level.star3, payload);
    return s3 ? 3 : 2;
  }

  static bool _check(StarObjective obj, MatchPayload payload) =>
      switch (obj.type) {
        ObjectiveType.win => payload.humanWon,
        ObjectiveType.margin => payload.margin >= (obj.min ?? 1),
        // maxMoves now uses human TURN count (chains = 1 turn).
        ObjectiveType.maxMoves => payload.humanTurnCount <= (obj.value ?? 999),
        // preventChain: true if the AI never captured ≥3 boxes in any single turn.
        ObjectiveType.preventChain => payload.aiMaxChainBoxes < 3,
        // maxAiBoxes: true if the AI's total final box count is within the cap.
        ObjectiveType.maxAiBoxes => payload.aiBoxCount <= (obj.value ?? 999),
        ObjectiveType.none => true,
      };
}
