import 'package:dot_clash/features/tutorial/domain/coach_tour_step.dart';
import 'package:dot_clash/features/tutorial/presentation/coach_tour_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CoachTourTargetRegistry.clearForTest);

  test('home and game targets use separate key maps', () {
    final gameOwner = Object();
    final homeKey = CoachTourTargetRegistry.keyForHome(
      CoachTourTargetId.homeCampaignHero,
    );
    final gameKey = CoachTourTargetRegistry.keyForGame(
      CoachTourTargetId.gameBoard,
      gameOwner,
    );
    expect(homeKey, isNot(same(gameKey)));
  });

  test('claiming a new game scope issues fresh GlobalKeys', () {
    final owner1 = Object();
    final owner2 = Object();
    final key1 = CoachTourTargetRegistry.keyForGame(
      CoachTourTargetId.gameBoard,
      owner1,
    );
    CoachTourTargetRegistry.claimGameScope(owner2);
    final key2 = CoachTourTargetRegistry.keyForGame(
      CoachTourTargetId.gameBoard,
      owner2,
    );
    expect(key1, isNot(same(key2)));
  });

  test('releaseAllGameTargets clears game keys but not home keys', () {
    final owner = Object();
    final gameKey1 = CoachTourTargetRegistry.keyForGame(
      CoachTourTargetId.gameScoreStrip,
      owner,
    );
    final homeKey1 = CoachTourTargetRegistry.keyForHome(
      CoachTourTargetId.homeTopBarLives,
    );
    CoachTourTargetRegistry.releaseAllGameTargets();
    final gameKey2 = CoachTourTargetRegistry.keyForGame(
      CoachTourTargetId.gameScoreStrip,
      owner,
    );
    final homeKey2 = CoachTourTargetRegistry.keyForHome(
      CoachTourTargetId.homeTopBarLives,
    );
    expect(gameKey1, isNot(same(gameKey2)));
    expect(homeKey1, same(homeKey2));
  });

  test('releaseGameScope only clears matching owner', () {
    final owner = Object();
    final key1 = CoachTourTargetRegistry.keyForGame(
      CoachTourTargetId.gameBoard,
      owner,
    );
    CoachTourTargetRegistry.releaseGameScope(Object());
    final keyAfterWrongOwner = CoachTourTargetRegistry.keyForGame(
      CoachTourTargetId.gameBoard,
      owner,
    );
    expect(key1, same(keyAfterWrongOwner));
    CoachTourTargetRegistry.releaseGameScope(owner);
    final key2 = CoachTourTargetRegistry.keyForGame(
      CoachTourTargetId.gameBoard,
      owner,
    );
    expect(key1, isNot(same(key2)));
  });
}
