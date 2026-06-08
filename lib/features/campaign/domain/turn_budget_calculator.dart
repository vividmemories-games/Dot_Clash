import 'dart:math';

import '../../game/domain/models/game_state.dart';
import '../domain/campaign_level.dart';

/// Computes default turn budgets for campaign levels.
abstract final class TurnBudgetCalculator {
  static int? budgetFor(CampaignLevel level) {
    if (level.turnBudget != null) return level.turnBudget;

    // World 1 + World 2 early: unlimited unless JSON sets turnBudget.
    if (level.worldId == 1) return null;
    if (level.worldId == 2 && level.index <= 5) return null;
    if (level.worldId == 2 && _isUnlimitedBreather(level)) return null;

    return _computedBudget(level);
  }

  static bool _isUnlimitedBreather(CampaignLevel level) {
    if (level.id == 'w2_l11') return true;
    if (level.id == 'w2_l07' || level.id == 'w2_l12') return true;
    if (level.id == 'w2_l08') return true;
    return false;
  }

  static int _computedBudget(CampaignLevel level) {
    final totalBoxes = (level.gridSize - 1) * (level.gridSize - 1) -
        level.disabledCells.length;

    // A real match is not "boxes-to-win" turns: most early/mid turns are
    // non-scoring setup lines. Model it as an opening (setup) phase plus a
    // scoring phase, where chains let each scoring turn claim several boxes.
    final setupTurns = (totalBoxes * 0.4).ceil();
    final scoringTurns =
        (totalBoxes * 0.55 / _chainEfficiency(level.aiDifficulty)).ceil();

    var budget = setupTurns + scoringTurns;

    budget += switch (level.aiDifficulty) {
      AiDifficulty.easy => 3,
      AiDifficulty.medium => 5,
      AiDifficulty.hard => 4,
    };

    if (level.isBoss) budget += 2;

    // Speed-themed worlds get a tighter window, but still a winnable one.
    if (level.worldId == 4) budget -= 2;

    // When 3-star is a maxMoves challenge, keep the hard lose budget above the
    // skill threshold so winning stays feasible even if 3 stars is missed.
    final maxMoves3 =
        level.star3.type == ObjectiveType.maxMoves ? level.star3.value : null;
    if (maxMoves3 != null) {
      final buffer = level.worldId == 4 ? 6 : 8;
      budget = max(budget, maxMoves3 + buffer);
    }

    return budget.clamp(14, 35);
  }

  /// Average boxes claimed per human scoring turn (higher = longer chains).
  static double _chainEfficiency(AiDifficulty difficulty) =>
      switch (difficulty) {
        AiDifficulty.easy => 1.4,
        AiDifficulty.medium => 1.6,
        AiDifficulty.hard => 1.8,
      };
}
