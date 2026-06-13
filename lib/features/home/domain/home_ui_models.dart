import 'package:flutter/foundation.dart';

@immutable
class DailyMission {
  const DailyMission({
    required this.id,
    required this.title,
    required this.progress,
    required this.target,
    required this.rewardCoins,
    this.claimed = false,
  });

  final String id;
  final String title;
  final int progress;
  final int target;
  final int rewardCoins;
  final bool claimed;

  bool get completed => progress >= target;
  bool get readyToClaim => completed && !claimed;
  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);
}

enum MatchOutcome { win, loss, tie }

@immutable
class RecentMatch {
  const RecentMatch({
    required this.outcome,
    required this.modeLabel,
    required this.opponentLabel,
    required this.playedAt,
    this.opponentUid,
  });

  final MatchOutcome outcome;
  final String modeLabel;
  final String opponentLabel;
  final DateTime playedAt;
  final String? opponentUid;
}
