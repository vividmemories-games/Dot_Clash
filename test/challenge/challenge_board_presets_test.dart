import 'package:dot_clash/features/game/domain/models/ai_preset.dart';
import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:dot_clash/features/game/domain/rules/game_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity vectors — keep in sync with functions/src/challenge_board_presets.test.ts
void main() {
  final fortressDisabled = AiPreset.byId('fortress')!.disabledCells;

  group('Challenge board preset parity', () {
    test('challenge_classic initial state matches server vectors', () {
      final state = GameState.initial(rows: 6, cols: 6, playerIds: const ['A', 'B']);
      expect(state.totalBoxes, 25);
      expect(GameRules.legalMoves(state).length, 60);
      expect(state.currentPlayerId, 'A');
      expect(state.isOver, isFalse);
    });

    test('challenge_blitz initial state matches server vectors', () {
      final state = GameState.initial(rows: 4, cols: 4, playerIds: const ['A', 'B']);
      expect(state.totalBoxes, 9);
      expect(GameRules.legalMoves(state).length, 24);
      expect(state.currentPlayerId, 'A');
      expect(state.isOver, isFalse);
    });

    test('challenge_fortress initial state matches server vectors', () {
      final state = GameState.initial(
        rows: 5,
        cols: 5,
        playerIds: const ['A', 'B'],
        disabledCells: fortressDisabled.toSet(),
      );
      expect(state.totalBoxes, 7);
      expect(GameRules.legalMoves(state).length, 22);
      expect(state.currentPlayerId, 'A');
      expect(state.isOver, isFalse);
      expect(
        state.disabledCells,
        {
          '1_1', '1_2', '1_3',
          '2_1', '2_2', '2_3',
          '3_1', '3_2', '3_3',
        },
      );
    });
  });
}
