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
    final boxesToLead = totalBoxes ~/ 2 + 1;

    final (expected, slack) = switch (level.aiDifficulty) {
      AiDifficulty.easy => (1.5, 5),
      AiDifficulty.medium => (1.8, 4),
      AiDifficulty.hard => (2.0, 3),
    };

    var budget = (boxesToLead / expected).ceil() + slack;

    if (level.isBoss) budget += 2;

    final maxMoves3 = level.star3.type == ObjectiveType.maxMoves
        ? level.star3.value
        : null;
    if (maxMoves3 != null) {
      if (level.id == 'w2_l06') return maxMoves3 + 5;
      if (level.worldId == 4) return maxMoves3 + 1;
      return maxMoves3 + 3;
    }

    if (level.worldId == 4) budget -= 4;

    return budget.clamp(8, 30);
  }
}
