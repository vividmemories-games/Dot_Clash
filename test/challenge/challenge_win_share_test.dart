import 'package:dot_clash/features/challenge/domain/challenge_win_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildText includes nostalgia hook score and series', () {
    final text = ChallengeWinShare.buildText(
      opponentName: 'Sam',
      myScore: 12,
      opponentScore: 8,
      seriesDisplay: '2–1–0',
    );
    expect(text, contains('Remember this game from class?'));
    expect(text, contains('Sam'));
    expect(text, contains('12–8'));
    expect(text, contains('Series: 2–1–0'));
  });

  test('buildText omits series when not provided', () {
    final text = ChallengeWinShare.buildText(
      opponentName: 'Alex',
      myScore: 5,
      opponentScore: 3,
    );
    expect(text, isNot(contains('Series:')));
  });
}
