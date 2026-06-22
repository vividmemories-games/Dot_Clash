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

/// Per-objective campaign star outcome (★, ★★, ★★★ evaluated independently).
class LevelEvaluation {
  const LevelEvaluation({
    required this.starsEarned,
    required this.objectivesMet,
  });

  static const empty = LevelEvaluation(
    starsEarned: 0,
    objectivesMet: [false, false, false],
  );

  /// Total stars (0–3): count of met objectives.
  final int starsEarned;

  /// Index 0 = ★, 1 = ★★, 2 = ★★★.
  final List<bool> objectivesMet;

  bool metForStar(int starNumber) =>
      starNumber >= 1 &&
      starNumber <= objectivesMet.length &&
      objectivesMet[starNumber - 1];
}

/// Evaluates the 3-star conditions for a campaign level.
abstract final class LevelEvaluator {
  /// Returns stars earned (0–3) for this match.
  static int evaluate(CampaignLevel level, MatchPayload payload) =>
      evaluateDetailed(level, payload).starsEarned;

  /// Returns per-objective results; each star tier is scored independently.
  static LevelEvaluation evaluateDetailed(
    CampaignLevel level,
    MatchPayload payload,
  ) {
    if (!payload.humanWon) return LevelEvaluation.empty;

    final met = [
      _check(level.star1, payload),
      _check(level.star2, payload),
      _check(level.star3, payload),
    ];
    final count = met.where((m) => m).length;
    return LevelEvaluation(starsEarned: count, objectivesMet: met);
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
