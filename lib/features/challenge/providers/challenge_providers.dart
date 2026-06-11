import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/challenge_repository.dart';
import '../domain/challenge_room.dart';

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return ChallengeRepository();
});

/// Live Firestore snapshot for `challenges/{code}`.
final challengeRoomProvider = StreamProvider.autoDispose
    .family<ChallengeRoom?, String>((ref, code) {
  return ref.watch(challengeRepositoryProvider).watchRoom(code);
});

/// Create a waiting room; returns normalized 6-char code.
final createChallengeProvider =
    FutureProvider.autoDispose.family<String, String?>(
  (ref, targetUid) async {
    return ref.read(challengeRepositoryProvider).createChallenge(
          targetUid: targetUid,
        );
  },
);

final joinChallengeProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, code) async {
    return ref.read(challengeRepositoryProvider).joinChallenge(code);
  },
);
