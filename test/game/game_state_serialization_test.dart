import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState serialization', () {
    test('round-trips empty disabledCells', () {
      final original = GameState.initial(rows: 6, cols: 6);
      final restored = GameState.fromJson(original.toJson());
      expect(restored.disabledCells, isEmpty);
      expect(restored.rows, 6);
      expect(restored.cols, 6);
      expect(restored.totalBoxes, original.totalBoxes);
    });

    test('round-trips non-empty disabledCells', () {
      final original = GameState.initial(
        rows: 5,
        cols: 5,
        disabledCells: {'0_1', '1_0', '2_2'},
      );
      final restored = GameState.fromJson(original.toJson());
      expect(restored.disabledCells, original.disabledCells);
      expect(restored.totalBoxes, original.totalBoxes);
    });

    test('fromJson defaults missing disabledCells to empty', () {
      final json = GameState.initial(rows: 3, cols: 3).toJson()
        ..remove('disabledCells');
      final restored = GameState.fromJson(json);
      expect(restored.disabledCells, isEmpty);
    });
  });
}
