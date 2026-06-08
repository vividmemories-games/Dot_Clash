import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../campaign/domain/daily_puzzle.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../domain/home_ui_models.dart';

/// Daily mission rows derived from the live profile.
final dailyMissionsProvider = Provider<List<DailyMission>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  final progress = profile?.dailyMissions.forToday() ??
      const DailyMissionProgress.empty().forToday();

  return [
    (
      id: 'win_matches',
      title: 'Win matches',
      target: 3,
      rewardCoins: 45,
    ),
    (
      id: 'play_games',
      title: 'Play games',
      target: 4,
      rewardCoins: 60,
    ),
    (
      id: 'capture_boxes',
      title: 'Capture boxes',
      target: 15,
      rewardCoins: 35,
    ),
  ].map((spec) {
    final progressValue = progress.progressFor(spec.id);
    return DailyMission(
      id: spec.id,
      title: spec.title,
      progress: progressValue,
      target: spec.target,
      rewardCoins: spec.rewardCoins,
      claimed: progress.isClaimed(spec.id),
    );
  }).toList();
});

final dailyPuzzleLevelIdProvider = Provider<String>((ref) {
  return DailyPuzzle.levelIdForToday();
});

final recentMatchesProvider = StreamProvider<List<RecentMatch>>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchRecentMatches().map(
        (records) => records
            .map(
              (r) => RecentMatch(
                outcome: switch (r.outcome) {
                  MatchResult.win => MatchOutcome.win,
                  MatchResult.loss => MatchOutcome.loss,
                  MatchResult.tie => MatchOutcome.tie,
                },
                modeLabel: r.modeLabel,
                opponentLabel: r.opponentLabel,
                playedAt: r.playedAt,
              ),
            )
            .toList(),
      );
});
