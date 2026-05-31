import 'package:dot_clash/features/tutorial/domain/coach_tour_catalog.dart';
import 'package:dot_clash/features/tutorial/domain/coach_tour_step.dart';
import 'package:dot_clash/features/campaign/domain/campaign_world.dart';
import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachTourSessionLogic w1_l01', () {
    late CoachTourSessionLogic logic;

    setUp(() {
      logic = CoachTourSessionLogic(
        tourId: 'campaign_ftue',
        steps: CoachTourCatalog.campaignStepsFor('w1_l01'),
      );
    });

    test('starts on draw step', () {
      expect(logic.currentStep?.id, 'l01_draw');
      expect(logic.showSkipButton, isFalse);
    });

    test('advances after human move', () {
      expect(logic.onHumanMove(), isTrue);
      expect(logic.currentStep?.id, 'l01_score');
    });

    test('shows extra turn on box claim', () {
      logic.onHumanMove();
      expect(logic.onHumanBoxClaimed(), isTrue);
      expect(logic.currentStep?.id, 'l01_extra_turn');
    });

    test('highlightEdge on draw step', () {
      final state = GameState.initial(rows: 5, cols: 5);
      expect(logic.highlightEdge(state), isNotNull);
    });
  });

  group('CoachTourSessionLogic w1_l03 timer skip', () {
    test('skips timer step when timer disabled', () {
      final logic = CoachTourSessionLogic(
        tourId: 'campaign_ftue',
        steps: CoachTourCatalog.campaignStepsFor('w1_l03'),
      );
      expect(logic.currentStep?.id, 'l03_timer');
      expect(logic.applyConditionalSkips(showTimer: false), isTrue);
      expect(logic.currentStep?.id, 'l03_hint');
    });

    test('hint step advances on NEXT fallback', () {
      final logic = CoachTourSessionLogic(
        tourId: 'campaign_ftue',
        steps: CoachTourCatalog.campaignStepsFor('w1_l03'),
      );
      logic.advanceNext(); // timer step
      expect(logic.currentStep?.id, 'l03_hint');
      expect(logic.advanceNext(), isTrue);
      expect(logic.currentStep?.id, 'l03_corners');
    });
  });

  group('CoachTourSessionLogic home tour', () {
    test('completes after all next steps', () {
      final logic = CoachTourSessionLogic(
        tourId: 'home_ftue_v1',
        steps: CoachTourCatalog.homeFtueSteps,
      );
      for (var i = 0; i < CoachTourCatalog.homeFtueSteps.length; i++) {
        expect(logic.isComplete, isFalse);
        logic.advanceNext();
      }
      expect(logic.isComplete, isTrue);
    });
  });

  group('FTUE catalog & world gates', () {
    test('campaign FTUE covers levels 1–4 only', () {
      expect(CoachTourCatalog.campaignFtueLevelIds, [
        'w1_l01',
        'w1_l02',
        'w1_l03',
        'w1_l04',
      ]);
      expect(CoachTourCatalog.isCampaignFtueLevel('w1_l05'), isFalse);
    });

    test('world 1 has mini boss at 5 and finale at 10', () {
      final world = CampaignCatalog.worldById(1);
      expect(world.bossLevelIndexes, [5, 10]);
    });
  });
}
