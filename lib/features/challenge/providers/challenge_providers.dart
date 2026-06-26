import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_providers.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge_room.dart';
import '../domain/create_challenge_result.dart';
import '../domain/head_to_head_stats.dart';

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return ChallengeRepository();
});

/// Live Firestore snapshot for `challenges/{code}`.
final challengeRoomProvider =
    StreamProvider.autoDispose.family<ChallengeRoom?, String>((ref, code) {
  return ref.watch(challengeRepositoryProvider).watchRoom(code);
});

/// Create a waiting room; returns server-resolved preset + code.
final createChallengeProvider = FutureProvider.autoDispose
    .family<CreateChallengeResult, CreateChallengeRequest>(
  (ref, request) async {
    return ref.read(challengeRepositoryProvider).createChallenge(
          targetUid: request.targetUid,
          boardPresetId: request.boardPresetId,
        );
  },
);

final joinChallengeProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, code) async {
    return ref.read(challengeRepositoryProvider).joinChallenge(code);
  },
);

/// Unique recent opponents from challenge match history (most recent first).
final challengeRivalsProvider =
    Provider<AsyncValue<List<ChallengeRival>>>((ref) {
  return ref.watch(challengeRecentMatchesProvider).whenData(
        HeadToHeadStats.recentRivals,
      );
});

/// Head-to-head W–L–T vs a specific opponent uid.
final headToHeadProvider =
    Provider.family<HeadToHeadRecord, String>((ref, opponentUid) {
  final matches =
      ref.watch(challengeRecentMatchesProvider).valueOrNull ?? const [];
  return HeadToHeadStats.forOpponent(matches, opponentUid);
});
