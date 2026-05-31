import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:dot_clash/features/tutorial/domain/tutorial_catalog.dart';
import 'package:dot_clash/features/tutorial/domain/tutorial_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorialSessionLogic w1_l01', () {
    late TutorialSessionLogic logic;

    setUp(() {
      logic = TutorialSessionLogic(
        levelId: 'w1_l01',
        steps: TutorialCatalog.stepsFor('w1_l01'),
      );
    });

    test('starts on draw step with edge highlight', () {
      expect(logic.currentStep?.id, 'w1_l01_draw');
      expect(logic.blocksInteraction, isFalse);
      expect(logic.showSkipButton, isFalse);
    });

    test('advances to boxes banner after human move', () {
      expect(logic.onHumanMove(), isTrue);
      expect(logic.currentStep?.id, 'w1_l01_boxes');
      expect(logic.blocksInteraction, isFalse);
      expect(logic.showSkipButton, isTrue);
    });

    test('shows extra turn step after human box claim', () {
      logic.onHumanMove();
      expect(logic.onHumanBoxClaimed(), isTrue);
      expect(logic.currentStep?.id, 'w1_l01_extra_turn');
    });

    test('completes after dismissing all banner steps', () {
      logic.onHumanMove();
      logic.onHumanBoxClaimed();
      expect(logic.dismissCurrentStep(), isTrue);
      expect(logic.isComplete, isTrue);
    });

    test('skipAll marks session complete', () {
      logic.skipAll();
      expect(logic.isComplete, isTrue);
      expect(logic.skipped, isTrue);
    });

    test('highlightEdge returns first legal move on draw step', () {
      final state = GameState.initial(rows: 5, cols: 5);
      final edge = logic.highlightEdge(state);
      expect(edge, isNotNull);
      expect(logic.allowedEdges(state), {edge});
    });
  });

  group('TutorialSessionLogic w1_l02', () {
    test('score step dismisses to complete', () {
      final logic = TutorialSessionLogic(
        levelId: 'w1_l02',
        steps: TutorialCatalog.stepsFor('w1_l02'),
      );
      expect(logic.currentStep?.highlightRegion, TutorialHighlightRegion.scoreStrip);
      expect(logic.dismissCurrentStep(), isTrue);
      expect(logic.isComplete, isTrue);
    });
  });

  group('TutorialSessionLogic w1_l03', () {
    test('corner tip is a single banner step', () {
      final logic = TutorialSessionLogic(
        levelId: 'w1_l03',
        steps: TutorialCatalog.stepsFor('w1_l03'),
      );
      expect(logic.currentStep?.presentation, TutorialPresentation.banner);
      expect(logic.dismissCurrentStep(), isTrue);
      expect(logic.isComplete, isTrue);
    });
  });
}
