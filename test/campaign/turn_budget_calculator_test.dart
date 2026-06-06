import 'package:dot_clash/features/campaign/domain/campaign_level.dart';
import 'package:dot_clash/features/campaign/domain/turn_budget_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [CampaignLevel] from a minimal JSON map matching the asset schema.
CampaignLevel _level({
  required String id,
  required int worldId,
  required int index,
  int gridSize = 6,
  String difficulty = 'medium',
  bool isBoss = false,
  Map<String, dynamic>? star3,
  int? turnBudget,
}) {
  return CampaignLevel.fromJson({
    'id': id,
    'worldId': worldId,
    'index': index,
    'title': id,
    'gridSize': gridSize,
    'aiDifficulty': difficulty,
    'isBoss': isBoss,
    'objectives': {
      'star1': {'type': 'win'},
      'star2': {'type': 'margin', 'min': 2},
      'star3': star3 ?? {'type': 'preventChain'},
    },
    if (turnBudget != null) 'turnBudget': turnBudget,
  });
}

void main() {
  group('TurnBudgetCalculator.budgetFor', () {
    test('w2_l09 Greedy Counter is winnable (>= 22 turns)', () {
      final level = _level(id: 'w2_l09', worldId: 2, index: 9);
      final budget = TurnBudgetCalculator.budgetFor(level);
      expect(budget, isNotNull);
      expect(budget!, greaterThanOrEqualTo(22));
    });

    test('explicit JSON turnBudget overrides the calculator', () {
      final level = _level(
        id: 'w2_l06',
        worldId: 2,
        index: 6,
        gridSize: 7,
        turnBudget: 25,
      );
      expect(TurnBudgetCalculator.budgetFor(level), 25);
    });

    test('World 1 levels stay unlimited', () {
      final level = _level(id: 'w1_l09', worldId: 1, index: 9);
      expect(TurnBudgetCalculator.budgetFor(level), isNull);
    });

    test('World 2 early levels (index <= 5) stay unlimited', () {
      final level = _level(id: 'w2_l03', worldId: 2, index: 3);
      expect(TurnBudgetCalculator.budgetFor(level), isNull);
    });

    test('World 2 breather levels stay unlimited', () {
      final level = _level(id: 'w2_l11', worldId: 2, index: 11);
      expect(TurnBudgetCalculator.budgetFor(level), isNull);
    });

    test('maxMoves star3 keeps a win buffer above the 3-star threshold', () {
      final level = _level(
        id: 'w4_l01',
        worldId: 4,
        index: 1,
        star3: {'type': 'maxMoves', 'value': 9},
      );
      final budget = TurnBudgetCalculator.budgetFor(level);
      expect(budget, isNotNull);
      expect(budget!, greaterThan(9));
    });

    test('larger grids get a larger budget', () {
      final small = _level(id: 'w2_l09', worldId: 2, index: 9, gridSize: 6);
      final large = _level(id: 'w2_l13', worldId: 2, index: 13, gridSize: 7);
      expect(
        TurnBudgetCalculator.budgetFor(large)!,
        greaterThan(TurnBudgetCalculator.budgetFor(small)!),
      );
    });
  });
}
