import '../../game/domain/models/game_state.dart';
import '../../game/domain/rules/game_rules.dart';

/// Pure metrics computed from a completed (or in-progress) [GameState].
///
/// All methods replay [GameState.moveHistory] to reconstruct turn segments,
/// which avoids storing extra metadata during gameplay.
abstract final class CampaignMoveMetrics {
  /// Number of distinct human control periods in [state].
  ///
  /// A control period starts the first time the human has the turn and ends
  /// when the turn passes to the AI. An entire chain of box completions in one
  /// go still counts as **one** human turn.
  ///
  ///   human line  →  human line (completes box)  →  human line  →  AI line
  ///   ↑____________________________ 1 turn _____↑
  static int humanTurnCount(GameState state, String humanPlayerId) {
    if (state.moveHistory.isEmpty) return 0;

    var turns = 0;
    var inHumanSegment = false;

    var current = GameState.initial(
      rows: state.rows,
      cols: state.cols,
      playerIds: state.playerIds,
      disabledCells: state.disabledCells,
    );

    for (final edge in state.moveHistory) {
      final isHumanTurn = current.currentPlayerId == humanPlayerId;

      if (isHumanTurn && !inHumanSegment) {
        turns++;
        inHumanSegment = true;
      } else if (!isHumanTurn) {
        inHumanSegment = false;
      }

      current = GameRules.applyMove(current, edge);
    }

    return turns;
  }

  /// Maximum number of boxes the AI claimed in **any single AI control period**.
  ///
  /// An AI control period is contiguous AI moves until the turn passes back to
  /// the human (or the game ends). Returns 0 if the AI never had a turn.
  static int aiMaxChainBoxes(GameState state, String humanPlayerId) {
    if (state.moveHistory.isEmpty) return 0;

    var maxInSegment = 0;
    var segmentBoxes = 0;
    var inAiSegment = false;

    final aiId = state.playerIds.firstWhere(
      (id) => id != humanPlayerId,
      orElse: () => state.playerIds.last,
    );

    var current = GameState.initial(
      rows: state.rows,
      cols: state.cols,
      playerIds: state.playerIds,
      disabledCells: state.disabledCells,
    );

    for (final edge in state.moveHistory) {
      final isAiTurn = current.currentPlayerId == aiId;

      if (isAiTurn && !inAiSegment) {
        // Start of a new AI segment — reset counter.
        segmentBoxes = 0;
        inAiSegment = true;
      } else if (!isAiTurn) {
        inAiSegment = false;
      }

      final boxesBefore = current.claimedBoxes.length;
      current = GameRules.applyMove(current, edge);
      final boxesAfter = current.claimedBoxes.length;

      if (isAiTurn) {
        segmentBoxes += boxesAfter - boxesBefore;
        if (segmentBoxes > maxInSegment) maxInSegment = segmentBoxes;
      }
    }

    return maxInSegment;
  }

  /// Move index in [GameState.moveHistory] where the AI's most recent control
  /// period began. Rewinding to this index restores the board to just before
  /// that AI run (used by Riposte).
  static int? lastAiControlPeriodStartMoveIndex(
    GameState state,
    String humanPlayerId,
  ) {
    if (state.moveHistory.isEmpty) return null;

    final aiId = state.playerIds.firstWhere(
      (id) => id != humanPlayerId,
      orElse: () => state.playerIds.last,
    );

    var current = GameState.initial(
      rows: state.rows,
      cols: state.cols,
      playerIds: state.playerIds,
      disabledCells: state.disabledCells,
    );

    int? lastStart;
    var inAiSegment = false;

    for (var i = 0; i < state.moveHistory.length; i++) {
      final isAiTurn = current.currentPlayerId == aiId;
      if (isAiTurn && !inAiSegment) {
        lastStart = i;
        inAiSegment = true;
      } else if (!isAiTurn) {
        inAiSegment = false;
      }
      current = GameRules.applyMove(current, state.moveHistory[i]);
    }

    return lastStart;
  }

  /// Final box count for the AI player.
  static int aiBoxCount(GameState state, String humanPlayerId) {
    final aiId = state.playerIds.firstWhere(
      (id) => id != humanPlayerId,
      orElse: () => state.playerIds.last,
    );
    return state.claimedBoxes.values.where((pid) => pid == aiId).length;
  }
}
