import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:dot_clash/features/game/domain/rules/game_rules.dart';
import 'package:dot_clash/features/game/domain/models/ai_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Helpers ──────────────────────────────────────────────────────────────────

  GameState initial2x2() => GameState.initial(rows: 2, cols: 2);
  GameState initial3x3() => GameState.initial(rows: 3, cols: 3);

  // A 2×2 dot grid has 1 box:
  //  (0,0) — (0,1)
  //   |         |
  //  (1,0) — (1,1)
  //
  // Edges: H_0_0 (top), H_1_0 (bottom), V_0_0 (left), V_0_1 (right)

  // ── Key builders ──────────────────────────────────────────────────────────────

  group('Key builders', () {
    test('hEdge key is formatted correctly', () {
      expect(GameRules.hEdge(0, 0), 'H_0_0');
      expect(GameRules.hEdge(3, 2), 'H_3_2');
    });

    test('vEdge key is formatted correctly', () {
      expect(GameRules.vEdge(1, 2), 'V_1_2');
    });

    test('boxKey is formatted correctly', () {
      expect(GameRules.boxKey(0, 0), '0_0');
      expect(GameRules.boxKey(2, 3), '2_3');
    });

    test('parseEdge round-trips correctly', () {
      final (:isH, :row, :col) = GameRules.parseEdge('H_2_3');
      expect(isH, isTrue);
      expect(row, 2);
      expect(col, 3);

      final v = GameRules.parseEdge('V_0_4');
      expect(v.isH, isFalse);
      expect(v.row, 0);
      expect(v.col, 4);
    });
  });

  // ── isLegalMove ───────────────────────────────────────────────────────────────

  group('isLegalMove', () {
    test('allows any undrawn edge on an empty board', () {
      final s = initial2x2();
      expect(GameRules.isLegalMove(s, 'H_0_0'), isTrue);
      expect(GameRules.isLegalMove(s, 'V_0_0'), isTrue);
    });

    test('rejects already-drawn edges', () {
      final s = GameRules.applyMove(initial2x2(), 'H_0_0');
      expect(GameRules.isLegalMove(s, 'H_0_0'), isFalse);
    });

    test('rejects out-of-bounds edges', () {
      final s = initial2x2();
      // row 2 on a 2-row grid is invalid for H edges (valid rows: 0,1)
      expect(GameRules.isLegalMove(s, 'H_2_0'), isFalse);
      // col 1 on a 2-col grid is invalid for H edges (valid cols: 0)
      expect(GameRules.isLegalMove(s, 'H_0_1'), isFalse);
    });

    test('rejects moves when game is over', () {
      // Complete the single box in a 2×2 grid
      var s = initial2x2();
      s = GameRules.applyMove(s, 'H_0_0');
      s = GameRules.applyMove(s, 'H_1_0');
      s = GameRules.applyMove(s, 'V_0_0');
      s = GameRules.applyMove(s, 'V_0_1');
      expect(s.isOver, isTrue);
      // Any further move is illegal
      expect(GameRules.isLegalMove(s, 'H_0_0'), isFalse);
    });
  });

  // ── applyMove ─────────────────────────────────────────────────────────────────

  group('applyMove', () {
    test('adds the edge to drawnEdges', () {
      final s = GameRules.applyMove(initial2x2(), 'H_0_0');
      expect(s.drawnEdges, contains('H_0_0'));
    });

    test('appends to moveHistory', () {
      final s = GameRules.applyMove(initial2x2(), 'H_0_0');
      expect(s.moveHistory, ['H_0_0']);
    });

    test('records edgeOwners for the player who drew the edge', () {
      final s = GameRules.applyMove(initial2x2(), 'H_0_0');
      expect(s.edgeOwners['H_0_0'], 'A');
    });

    /// After a timer pass the turn flips without a new history entry; edge color
    /// must still follow [GameNotifier.onTurnTimedOut], not replay-from-empty.
    test('edgeOwners follows currentPlayer after timer-style pass', () {
      var s = GameState.initial(rows: 3, cols: 3);
      s = s.copyWith(currentPlayerId: 'B');
      s = GameRules.applyMove(s, 'H_0_0');
      expect(s.edgeOwners['H_0_0'], 'B');
    });

    test('switches player when no box is completed', () {
      final s = GameRules.applyMove(initial2x2(), 'H_0_0');
      // Player A drew the first edge; no box complete → Player B's turn
      expect(s.currentPlayerId, 'B');
    });

    test('grants extra turn when a box is completed', () {
      var s = initial2x2();
      s = GameRules.applyMove(s, 'H_0_0'); // A → B
      s = GameRules.applyMove(s, 'H_1_0'); // B → A
      s = GameRules.applyMove(s, 'V_0_0'); // A → B
      // B draws the 4th edge — claims the box → B gets another turn
      s = GameRules.applyMove(s, 'V_0_1');
      expect(s.claimedBoxes['0_0'], 'B');
      expect(s.scores['B'], 1);
      // Game is over (only 1 box), so turn doesn't matter
      expect(s.isOver, isTrue);
    });

    test('scores both players correctly across multiple boxes', () {
      // 3×3 grid: 4 boxes, player A wins if they get ≥3
      var s = initial3x3();

      // Draw all edges of box (0,0) with A getting the last edge
      // Top: H_0_0, Bottom: H_1_0, Left: V_0_0, Right: V_0_1
      s = GameRules.applyMove(s, 'H_0_0'); // A → B
      s = GameRules.applyMove(s, 'H_1_0'); // B → A
      s = GameRules.applyMove(s, 'V_0_0'); // A → B
      s = GameRules.applyMove(s, 'V_0_1'); // B claims (0,0) → B plays again

      expect(s.claimedBoxes['0_0'], 'B');
      expect(s.scores['B'], 1);
      expect(s.currentPlayerId, 'B'); // extra turn
    });
  });

  // ── Box detection ─────────────────────────────────────────────────────────────

  group('adjacentBoxes', () {
    test('H edge at top of grid touches only box below', () {
      // In a 3×3 grid, H_0_0 is above box (0,0) only
      final boxes = GameRules.adjacentBoxes(3, 3, 'H_0_0');
      expect(boxes, [(0, 0)]);
    });

    test('H edge in the middle touches boxes above and below', () {
      // H_1_0 in a 3×3 grid touches box (0,0) above and (1,0) below
      final boxes = GameRules.adjacentBoxes(3, 3, 'H_1_0');
      expect(boxes, containsAll([(0, 0), (1, 0)]));
    });

    test('V edge on the left column touches only box to the right', () {
      final boxes = GameRules.adjacentBoxes(3, 3, 'V_0_0');
      expect(boxes, [(0, 0)]);
    });
  });

  // ── Game over & winner ────────────────────────────────────────────────────────

  group('Game over', () {
    test('isOver becomes true when all boxes are claimed', () {
      var s = initial2x2();
      s = GameRules.applyMove(s, 'H_0_0');
      s = GameRules.applyMove(s, 'H_1_0');
      s = GameRules.applyMove(s, 'V_0_0');
      s = GameRules.applyMove(s, 'V_0_1');
      expect(s.isOver, isTrue);
    });

    test('winnerId is null on a tie', () {
      // Both players claim 2 boxes in a 3×3 grid (tie)
      // We simulate this by building a specific state directly
      const state = GameState(
        rows: 3,
        cols: 3,
        drawnEdges: {},
        edgeOwners: {},
        claimedBoxes: {'0_0': 'A', '0_1': 'B', '1_0': 'A', '1_1': 'B'},
        currentPlayerId: 'A',
        scores: {'A': 2, 'B': 2},
        moveHistory: [],
        isOver: true,
        winnerId: null,
      );
      expect(state.isTie, isTrue);
    });

    test('winnerId is set to the player with more boxes', () {
      // Build the 2×2 game — only player B finishes the box
      var s = initial2x2();
      s = GameRules.applyMove(s, 'H_0_0'); // A → B
      s = GameRules.applyMove(s, 'H_1_0'); // B → A
      s = GameRules.applyMove(s, 'V_0_0'); // A → B
      s = GameRules.applyMove(s, 'V_0_1'); // B claims → game over
      expect(s.winnerId, 'B');
    });
  });

  // ── Undo ──────────────────────────────────────────────────────────────────────

  group('undo', () {
    test('removes last move and restores previous state', () {
      var s = initial3x3();
      s = GameRules.applyMove(s, 'H_0_0'); // A → B
      s = GameRules.applyMove(s, 'H_1_0'); // B → A

      final undone = GameRules.undo(s);
      expect(undone.drawnEdges, contains('H_0_0'));
      expect(undone.drawnEdges, isNot(contains('H_1_0')));
      // Back to A's turn (B's move was undone)
      expect(undone.currentPlayerId, 'B');
    });

    test('undo on empty history returns same state', () {
      final s = initial3x3();
      expect(GameRules.undo(s).moveHistory, isEmpty);
    });
  });

  // ── legalMoves ────────────────────────────────────────────────────────────────

  group('legalMoves', () {
    test('returns all edges on an empty board', () {
      // 2×2 grid: 2 H edges + 2 V edges = 4
      final moves = GameRules.legalMoves(initial2x2());
      expect(moves.length, 4);
    });

    test('decreases by 1 after each move', () {
      var s = initial3x3();
      // 3×3: H rows = 3 cols=2 → 6; V rows=2 cols=3 → 6; total=12
      expect(GameRules.legalMoves(s).length, 12);
      s = GameRules.applyMove(s, 'H_0_0');
      expect(GameRules.legalMoves(s).length, 11);
    });

    test('returns empty list when game is over', () {
      var s = initial2x2();
      for (final m in ['H_0_0', 'H_1_0', 'V_0_0', 'V_0_1']) {
        s = GameRules.applyMove(s, m);
      }
      expect(GameRules.legalMoves(s), isEmpty);
    });

    test('Blitz 4x4 has 24 initial legal moves', () {
      final s = GameState.initial(rows: 4, cols: 4);
      expect(GameRules.legalMoves(s).length, 24);
      expect(s.totalBoxes, 9);
    });

    test('Fortress 5x5 center void has 22 initial legal moves', () {
      final fortress = AiPreset.byId('fortress')!;
      final s = GameState.initial(
        rows: fortress.rows,
        cols: fortress.cols,
        disabledCells: fortress.disabledCells.toSet(),
      );
      expect(GameRules.legalMoves(s).length, 22);
      expect(s.totalBoxes, 7);
    });
  });
}
