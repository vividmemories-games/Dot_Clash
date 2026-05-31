import 'dart:math';

import '../game/domain/models/game_state.dart';
import '../game/domain/rules/game_rules.dart';

/// Selects a move for the AI player at a given difficulty level.
abstract final class AiPlayer {
  static final _rng = Random();

  /// Returns an edge key, or null if there are no legal moves.
  ///
  /// When [persona] is provided (boss levels), it overrides the strategy while
  /// still honouring [difficulty] as the floor.
  static String? pickMove(
    GameState state,
    AiDifficulty difficulty, {
    BossPersona? persona,
  }) {
    final moves = GameRules.legalMoves(state);
    if (moves.isEmpty) return null;

    if (persona != null) {
      return _bossMove(state, moves, persona);
    }

    return switch (difficulty) {
      AiDifficulty.easy => _easyMove(state, moves),
      AiDifficulty.medium => _greedyMove(state, moves),
      AiDifficulty.hard => _strategicMove(state, moves),
    };
  }

  // ── Boss personas ─────────────────────────────────────────────────────────

  /// Boss moves are always hard-level aggressive — no random fallbacks.
  static String _bossMove(
    GameState state,
    List<String> moves,
    BossPersona persona,
  ) =>
      switch (persona) {
        BossPersona.machine => _machineMove(state, moves),
        BossPersona.trapper => _trapperMove(state, moves),
        BossPersona.collector => _collectorMove(state, moves),
      };

  /// The Machine: chain-aware strategic play, never falls back to random.
  static String _machineMove(GameState state, List<String> moves) {
    // Complete any box immediately
    for (final edge in _shuffled(moves)) {
      if (_completesBox(state, edge)) return edge;
    }
    // Safe moves only
    final safe = moves.where((e) => !_givesOpponentThirdEdge(state, e)).toList();
    if (safe.isNotEmpty) return safe[_rng.nextInt(safe.length)];
    // Sacrifice smallest chain — never random
    String? best;
    int bestLoss = 999;
    for (final edge in moves) {
      final loss = _estimateChainLoss(state, edge);
      if (loss < bestLoss) {
        bestLoss = loss;
        best = edge;
      }
    }
    return best ?? moves.first;
  }

  /// The Trapper: creates 3-edge traps (gives opponent near-complete boxes
  /// only when the chain runs deep enough to recapture immediately after).
  static String _trapperMove(GameState state, List<String> moves) {
    // Always take immediate completions first
    for (final edge in _shuffled(moves)) {
      if (_completesBox(state, edge)) return edge;
    }
    // Prefer moves that open a 3-edge box only if chain loss ≥ 2
    // (sets a trap: opponent takes 1, we recapture the chain)
    final trapMoves = moves.where((e) {
      if (!_givesOpponentThirdEdge(state, e)) return false;
      return _estimateChainLoss(state, e) >= 2;
    }).toList();
    if (trapMoves.isNotEmpty) return trapMoves[_rng.nextInt(trapMoves.length)];
    // Fall back to machine strategy
    return _machineMove(state, moves);
  }

  /// The Collector: hyper-greedy — always completes any available box, then
  /// extends existing chains before playing safe.
  static String _collectorMove(GameState state, List<String> moves) {
    // Take everything completable right now
    for (final edge in _shuffled(moves)) {
      if (_completesBox(state, edge)) return edge;
    }
    // Extend a chain: prefer moves adjacent to 2-edge boxes (sets up next turn)
    final chainExtenders = moves.where((e) {
      for (final (r, c) in GameRules.adjacentBoxes(state.rows, state.cols, e)) {
        if (!state.claimedBoxes.containsKey(GameRules.boxKey(r, c)) &&
            GameRules.edgesDrawnForBox(state, r, c) == 2) {
          return true;
        }
      }
      return false;
    }).toList();
    if (chainExtenders.isNotEmpty) {
      return chainExtenders[_rng.nextInt(chainExtenders.length)];
    }
    return _machineMove(state, moves);
  }

  // ── Easy: take obvious boxes, otherwise random ──────────────────────────────

  static String _easyMove(GameState state, List<String> moves) {
    for (final edge in _shuffled(moves)) {
      if (_completesBox(state, edge)) return edge;
    }
    return _randomMove(moves);
  }

  static String _randomMove(List<String> moves) {
    return moves[_rng.nextInt(moves.length)];
  }

  // ── Medium: greedy ────────────────────────────────────────────────────────────
  // Priority: (1) complete a box, (2) avoid giving a 3rd edge to a box,
  //           (3) random.

  static String _greedyMove(GameState state, List<String> moves) {
    // 1. Take any box that can be completed right now
    for (final edge in _shuffled(moves)) {
      if (_completesBox(state, edge)) return edge;
    }

    // 2. Prefer moves that don't give opponent a 3rd edge on any box
    final safe = moves
        .where((e) => !_givesOpponentThirdEdge(state, e))
        .toList();
    if (safe.isNotEmpty) return safe[_rng.nextInt(safe.length)];

    // 3. All moves are "risky" – just pick randomly
    return _randomMove(moves);
  }

  // ── Hard: chain-aware ─────────────────────────────────────────────────────────
  // Priority: (1) complete box(es), (2) sacrifice smallest chain if forced,
  //           (3) safe move, (4) random.

  static String _strategicMove(GameState state, List<String> moves) {
    // 1. Complete all immediate boxes greedily
    for (final edge in _shuffled(moves)) {
      if (_completesBox(state, edge)) return edge;
    }

    // 2. Safe moves (don't open a box for opponent)
    final safe = moves
        .where((e) => !_givesOpponentThirdEdge(state, e))
        .toList();
    if (safe.isNotEmpty) return safe[_rng.nextInt(safe.length)];

    // 3. Forced — pick the move that sacrifices the fewest boxes in a chain
    String? bestSacrifice;
    int bestLoss = 999;

    for (final edge in moves) {
      final loss = _estimateChainLoss(state, edge);
      if (loss < bestLoss) {
        bestLoss = loss;
        bestSacrifice = edge;
      }
    }
    return bestSacrifice ?? _randomMove(moves);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  /// True if playing this edge immediately completes ≥1 box.
  static bool _completesBox(GameState state, String edge) {
    for (final (r, c) in GameRules.adjacentBoxes(state.rows, state.cols, edge)) {
      final key = GameRules.boxKey(r, c);
      if (!state.claimedBoxes.containsKey(key) &&
          GameRules.edgesDrawnForBox(state, r, c) == 3) {
        return true;
      }
    }
    return false;
  }

  /// True if playing this edge would leave any adjacent unclaimed box with
  /// exactly 3 drawn edges (handing the opponent a capture next turn).
  static bool _givesOpponentThirdEdge(GameState state, String edge) {
    final futureEdges = {...state.drawnEdges, edge};
    for (final (r, c) in GameRules.adjacentBoxes(state.rows, state.cols, edge)) {
      final key = GameRules.boxKey(r, c);
      if (state.claimedBoxes.containsKey(key)) continue;
      final drawn = GameRules.boxEdges(r, c).where(futureEdges.contains).length;
      if (drawn == 3) return true;
    }
    return false;
  }

  /// Estimate how many boxes the opponent would capture in the resulting chain
  /// after we play this edge (simplified flood-fill).
  static int _estimateChainLoss(GameState state, String edge) {
    final nextState = GameRules.applyMove(state, edge);
    // Count all boxes that become immediately capturable for the opponent
    int loss = 0;
    for (var r = 0; r < state.rows - 1; r++) {
      for (var c = 0; c < state.cols - 1; c++) {
        final key = GameRules.boxKey(r, c);
        if (!nextState.claimedBoxes.containsKey(key) &&
            GameRules.edgesDrawnForBox(nextState, r, c) == 3) {
          loss++;
        }
      }
    }
    return loss;
  }

  static List<T> _shuffled<T>(List<T> list) => [...list]..shuffle(_rng);
}
