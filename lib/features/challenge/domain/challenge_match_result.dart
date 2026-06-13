import '../../profile/data/profile_repository.dart';
import 'challenge_room.dart';

/// Authoritative win/loss/tie from server [ChallengeRoom.winnerUid].
MatchResult challengeMatchResult(ChallengeRoom room, String? myUid) {
  final winnerUid = room.winnerUid;
  if (winnerUid == null) return MatchResult.tie;
  if (myUid == null || myUid.isEmpty) return MatchResult.loss;
  return winnerUid == myUid ? MatchResult.win : MatchResult.loss;
}

/// Dialog labels derived from the same room authority as settlement.
({bool iWon, bool isTie}) challengeResultLabels(
  ChallengeRoom room,
  String myUid,
) {
  final result = challengeMatchResult(room, myUid);
  return (
    iWon: result == MatchResult.win,
    isTie: result == MatchResult.tie,
  );
}
