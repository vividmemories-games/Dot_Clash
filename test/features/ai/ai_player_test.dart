import 'package:dot_clash/features/ai/ai_player.dart';
import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:dot_clash/features/game/domain/rules/game_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiPlayer easy', () {
    test('always completes an available box', () {
      var state = GameState.initial(rows: 3, cols: 3);
      state = state.copyWith(
        drawnEdges: {'H_0_0', 'H_1_0', 'V_0_0'},
        currentPlayerId: 'B',
      );

      for (var i = 0; i < 20; i++) {
        final move = AiPlayer.pickMove(state, AiDifficulty.easy);
        expect(move, 'V_0_1');
      }
    });

    test('picks a legal move when no box can be completed', () {
      final state = GameState.initial(rows: 3, cols: 3);

      for (var i = 0; i < 20; i++) {
        final move = AiPlayer.pickMove(state, AiDifficulty.easy);
        expect(GameRules.legalMoves(state), contains(move));
      }
    });
  });
}
