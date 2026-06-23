import 'package:dot_clash/features/campaign/domain/campaign_level.dart';
import 'package:dot_clash/features/campaign/domain/level_evaluator.dart';
import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CampaignLevel level0({
    required StarObjective star1,
    required StarObjective star2,
    required StarObjective star3,
  }) =>
      CampaignLevel(
        id: 'test',
        worldId: 1,
        index: 1,
        title: 'Test',
        gridSize: 5,
        aiDifficulty: AiDifficulty.easy,
        isBoss: false,
        star1: star1,
        star2: star2,
        star3: star3,
      );

  GameState humanWinState({required int humanScore, required int aiScore}) {
    const human = 'H';
    return GameState(
      rows: 3,
      cols: 3,
      drawnEdges: const {},
      edgeOwners: const {},
      claimedBoxes: const {},
      currentPlayerId: human,
      scores: {human: humanScore, 'B': aiScore},
      moveHistory: const [],
      isOver: true,
      winnerId: human,
      playerIds: const [human, 'B'],
    );
  }

  group('LevelEvaluator independent objectives', () {
    test('returns 0 when human loses', () {
      final state = GameState.initial(
        rows: 3,
        cols: 3,
        playerIds: const ['H', 'B'],
      );
      final payload = MatchPayload(finalState: state, humanPlayerId: 'H');
      final level = level0(
        star1: StarObjective.win(),
        star2: StarObjective.margin(1),
        star3: StarObjective.margin(3),
      );

      expect(LevelEvaluator.evaluate(level, payload), 0);
      expect(LevelEvaluator.evaluateDetailed(level, payload),
          LevelEvaluation.empty);
    });

    test('star2 missed but star3 met awards 2 stars (not gated)', () {
      final level = level0(
        star1: StarObjective.win(),
        star2: StarObjective.margin(5),
        star3: StarObjective.margin(2),
      );
      final payload = MatchPayload(
        finalState: humanWinState(humanScore: 4, aiScore: 1),
        humanPlayerId: 'H',
      );

      final result = LevelEvaluator.evaluateDetailed(level, payload);
      expect(result.objectivesMet, [true, false, true]);
      expect(result.starsEarned, 2);
    });

    test('all three objectives met yields 3 stars', () {
      final level = level0(
        star1: StarObjective.win(),
        star2: StarObjective.margin(1),
        star3: StarObjective.margin(2),
      );
      final payload = MatchPayload(
        finalState: humanWinState(humanScore: 3, aiScore: 0),
        humanPlayerId: 'H',
      );

      final result = LevelEvaluator.evaluateDetailed(level, payload);
      expect(result.objectivesMet, [true, true, true]);
      expect(result.starsEarned, 3);
    });

    test('only star1 met yields 1 star', () {
      final level = level0(
        star1: StarObjective.win(),
        star2: StarObjective.margin(5),
        star3: StarObjective.margin(10),
      );
      final payload = MatchPayload(
        finalState: humanWinState(humanScore: 1, aiScore: 0),
        humanPlayerId: 'H',
      );

      final result = LevelEvaluator.evaluateDetailed(level, payload);
      expect(result.objectivesMet, [true, false, false]);
      expect(result.starsEarned, 1);
    });
  });
}
