import '../models/game_state.dart';

/// Pure Dart Dots & Boxes rules engine.
/// No Flutter or Firebase dependencies — safe to copy into Cloud Functions.
abstract final class GameRules {
  // ── Key builders ────────────────────────────────────────────────────────────

  static String hEdge(int row, int col) => 'H_${row}_$col';
  static String vEdge(int row, int col) => 'V_${row}_$col';
  static String boxKey(int row, int col) => '${row}_$col';

  // ── Edge metadata ───────────────────────────────────────────────────────────

  /// Parse edge key back into components.
  static ({bool isH, int row, int col}) parseEdge(String key) {
    final parts = key.split('_');
    return (
      isH: parts[0] == 'H',
      row: int.parse(parts[1]),
      col: int.parse(parts[2]),
    );
  }

  /// All 4 edge keys that surround a box at (row, col).
  static List<String> boxEdges(int row, int col) => [
        hEdge(row, col),      // top
        hEdge(row + 1, col),  // bottom
        vEdge(row, col),      // left
        vEdge(row, col + 1),  // right
      ];

  /// Which box grid-coordinates does this edge border?
  /// A horizontal edge borders the box above and below it.
  /// A vertical edge borders the box to the left and right of it.
  static List<(int, int)> adjacentBoxes(
      int rows, int cols, String edgeKey) {
    final (:isH, :row, :col) = parseEdge(edgeKey);
    final result = <(int, int)>[];

    if (isH) {
      // Box above: (row-1, col)
      if (row > 0 && col < cols - 1) result.add((row - 1, col));
      // Box below: (row, col)
      if (row < rows - 1 && col < cols - 1) result.add((row, col));
    } else {
      // Box to the left: (row, col-1)
      if (col > 0 && row < rows - 1) result.add((row, col - 1));
      // Box to the right: (row, col)
      if (col < cols - 1 && row < rows - 1) result.add((row, col));
    }
    return result;
  }

  // ── Disabled-cell helpers ───────────────────────────────────────────────────

  /// Returns true if every adjacent box to this edge is disabled.
  /// Such edges are internal to disabled regions and should not be playable.
  static bool _isEdgeInDisabledRegion(GameState state, String edgeKey) {
    if (state.disabledCells.isEmpty) return false;
    final adjacent = adjacentBoxes(state.rows, state.cols, edgeKey);
    if (adjacent.isEmpty) return false;
    return adjacent.every((rc) => state.disabledCells.contains(boxKey(rc.$1, rc.$2)));
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  static bool isLegalMove(GameState state, String edgeKey) {
    if (state.isOver) return false;
    if (state.drawnEdges.contains(edgeKey)) return false;

    final (:isH, :row, :col) = parseEdge(edgeKey);
    bool inBounds;
    if (isH) {
      inBounds = row >= 0 && row < state.rows && col >= 0 && col < state.cols - 1;
    } else {
      inBounds = row >= 0 && row < state.rows - 1 && col >= 0 && col < state.cols;
    }
    if (!inBounds) return false;
    if (_isEdgeInDisabledRegion(state, edgeKey)) return false;
    return true;
  }

  // ── Move application ────────────────────────────────────────────────────────

  /// Apply an edge placement to the state, returning the new state.
  /// Handles box detection, scoring, extra-turn rule, and game-end.
  static GameState applyMove(GameState state, String edgeKey) {
    assert(isLegalMove(state, edgeKey),
        'Illegal move: $edgeKey on $state');

    final newEdges = {...state.drawnEdges, edgeKey};

    final newEdgeOwners = Map<String, String>.from(state.edgeOwners);
    newEdgeOwners[edgeKey] = state.currentPlayerId;

    // Find boxes that are now complete due to this edge
    final newlyClaimed = <String>[];
    for (final (r, c) in adjacentBoxes(state.rows, state.cols, edgeKey)) {
      final bKey = boxKey(r, c);
      if (state.disabledCells.contains(bKey)) continue; // masked out
      if (state.claimedBoxes.containsKey(bKey)) continue; // already owned

      final edges = boxEdges(r, c);
      if (edges.every(newEdges.contains)) {
        newlyClaimed.add(bKey);
      }
    }

    // Update claimed boxes and scores
    final newClaimed = Map<String, String>.from(state.claimedBoxes);
    final newScores = Map<String, int>.from(state.scores);

    for (final bKey in newlyClaimed) {
      newClaimed[bKey] = state.currentPlayerId;
      newScores[state.currentPlayerId] =
          (newScores[state.currentPlayerId] ?? 0) + 1;
    }

    // Scoring a box grants an extra turn; otherwise the turn switches
    final nextPlayer = newlyClaimed.isNotEmpty
        ? state.currentPlayerId
        : state.opponentOf;

    // Check game over (all boxes claimed)
    final isOver = newClaimed.length == state.totalBoxes;

    String? winner;
    if (isOver) {
      final ids = state.playerIds;
      final aScore = newScores[ids[0]] ?? 0;
      final bScore = newScores[ids[1]] ?? 0;
      if (aScore > bScore) {
        winner = ids[0];
      } else if (bScore > aScore) {
        winner = ids[1];
      }
      // else: tie → winner stays null
    }

    return state.copyWith(
      drawnEdges: newEdges,
      edgeOwners: newEdgeOwners,
      claimedBoxes: newClaimed,
      scores: newScores,
      currentPlayerId: nextPlayer,
      moveHistory: [...state.moveHistory, edgeKey],
      isOver: isOver,
      winnerId: winner,
      clearWinner: isOver && winner == null, // explicit tie
    );
  }

  // ── Undo ────────────────────────────────────────────────────────────────────

  /// Rebuild state by replaying all moves except the last one.
  static GameState undo(GameState state) {
    if (state.moveHistory.isEmpty) return state;

    final moves = state.moveHistory.sublist(0, state.moveHistory.length - 1);
    var rebuilt = GameState.initial(
      rows: state.rows,
      cols: state.cols,
      playerIds: state.playerIds,
      disabledCells: state.disabledCells,
    );
    for (final m in moves) {
      rebuilt = applyMove(rebuilt, m);
    }
    return rebuilt;
  }

  // ── Legal-move enumeration ───────────────────────────────────────────────────

  /// All legal moves for the current state (undrawn valid edges).
  static List<String> legalMoves(GameState state) {
    final moves = <String>[];
    for (var r = 0; r < state.rows; r++) {
      for (var c = 0; c < state.cols - 1; c++) {
        final k = hEdge(r, c);
        if (isLegalMove(state, k)) moves.add(k);
      }
    }
    for (var r = 0; r < state.rows - 1; r++) {
      for (var c = 0; c < state.cols; c++) {
        final k = vEdge(r, c);
        if (isLegalMove(state, k)) moves.add(k);
      }
    }
    return moves;
  }

  /// How many of the 4 surrounding edges of a box are already drawn?
  static int edgesDrawnForBox(
      GameState state, int boxRow, int boxCol) {
    return boxEdges(boxRow, boxCol)
        .where(state.drawnEdges.contains)
        .length;
  }

  /// Returns all box coordinates where exactly 3 edges are drawn
  /// (i.e., one move away from being captured).
  static List<(int, int)> chainableBoxes(GameState state) {
    final result = <(int, int)>[];
    for (var r = 0; r < state.rows - 1; r++) {
      for (var c = 0; c < state.cols - 1; c++) {
        if (!state.claimedBoxes.containsKey(boxKey(r, c)) &&
            edgesDrawnForBox(state, r, c) == 3) {
          result.add((r, c));
        }
      }
    }
    return result;
  }
}
