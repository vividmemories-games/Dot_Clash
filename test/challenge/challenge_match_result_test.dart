import 'package:dot_clash/features/challenge/domain/challenge_match_result.dart';
import 'package:dot_clash/features/challenge/domain/challenge_room.dart';
import 'package:dot_clash/features/challenge/domain/challenge_status.dart';
import 'package:dot_clash/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ChallengeRoom _room({
  String? winnerUid,
  ChallengeStatus status = ChallengeStatus.finished,
}) {
  return ChallengeRoom(
    code: 'ABC123',
    hostUid: 'host',
    hostDisplayName: 'Alex',
    guestUid: 'guest',
    guestDisplayName: 'Sam',
    status: status,
    rows: 6,
    cols: 6,
    version: 1,
    winnerUid: winnerUid,
    expiresAt: null,
    lastActivityAt: null,
    gameState: null,
    turnStartedAt: null,
  );
}

void main() {
  group('challengeMatchResult', () {
    test('host win from room.winnerUid', () {
      expect(
        challengeMatchResult(_room(winnerUid: 'host'), 'host'),
        MatchResult.win,
      );
      expect(
        challengeMatchResult(_room(winnerUid: 'host'), 'guest'),
        MatchResult.loss,
      );
    });

    test('tie when winnerUid is null', () {
      expect(
        challengeMatchResult(_room(winnerUid: null), 'host'),
        MatchResult.tie,
      );
    });
  });
}
