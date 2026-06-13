import '../../home/domain/home_ui_models.dart';

/// Win–loss–tie record vs one opponent.
class HeadToHeadRecord {
  const HeadToHeadRecord({
    required this.wins,
    required this.losses,
    required this.ties,
  });

  final int wins;
  final int losses;
  final int ties;

  int get total => wins + losses + ties;

  bool get hasHistory => total > 0;

  /// Display as `W–L–T` (e.g. `2–1–0`).
  String get display => '$wins–$losses–$ties';

  HeadToHeadRecord withOutcome(MatchOutcome outcome) {
    return switch (outcome) {
      MatchOutcome.win => HeadToHeadRecord(
          wins: wins + 1,
          losses: losses,
          ties: ties,
        ),
      MatchOutcome.loss => HeadToHeadRecord(
          wins: wins,
          losses: losses + 1,
          ties: ties,
        ),
      MatchOutcome.tie => HeadToHeadRecord(
          wins: wins,
          losses: losses,
          ties: ties + 1,
        ),
    };
  }
}

/// Recent opponent surfaced for re-challenge.
class ChallengeRival {
  const ChallengeRival({
    required this.uid,
    required this.displayName,
    required this.lastPlayedAt,
    required this.record,
    required this.lastOutcome,
    required this.currentStreak,
    required this.recentResults,
  });

  final String uid;
  final String displayName;
  final DateTime lastPlayedAt;
  final HeadToHeadRecord record;
  final MatchOutcome lastOutcome;
  /// Positive = consecutive wins vs opponent; negative = consecutive losses.
  final int currentStreak;
  /// Newest-first individual results vs this opponent (Profile shows up to 3).
  final List<RecentMatch> recentResults;

  String get rechallengeLabel =>
      lastOutcome == MatchOutcome.loss ? 'REVENGE' : 'REMATCH';

  String get streakLabel {
    if (currentStreak == 0) return 'No streak';
    if (currentStreak > 0) {
      return '$currentStreak-win streak';
    }
    return '${currentStreak.abs()}-loss streak';
  }
}

/// Aggregates challenge match history by [RecentMatch.opponentUid].
abstract final class HeadToHeadStats {
  static Iterable<RecentMatch> _challengeMatches(Iterable<RecentMatch> matches) {
    return matches.where(
      (m) => m.modeLabel == 'Challenge' && m.opponentUid != null,
    );
  }

  static List<RecentMatch> _matchesForOpponent(
    Iterable<RecentMatch> matches,
    String opponentUid,
  ) {
    return _challengeMatches(matches)
        .where((m) => m.opponentUid == opponentUid)
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  static HeadToHeadRecord forOpponent(
    Iterable<RecentMatch> matches,
    String opponentUid, {
    MatchOutcome? includeCurrent,
  }) {
    var record = const HeadToHeadRecord(wins: 0, losses: 0, ties: 0);
    for (final match in _matchesForOpponent(matches, opponentUid)) {
      record = record.withOutcome(match.outcome);
    }
    if (includeCurrent != null) {
      record = record.withOutcome(includeCurrent);
    }
    return record;
  }

  /// Consecutive wins (+) or losses (-) vs one opponent from most recent match.
  /// Ties break the streak.
  static int currentStreak(
    Iterable<RecentMatch> matches,
    String opponentUid,
  ) {
    final opponentMatches = _matchesForOpponent(matches, opponentUid);
    if (opponentMatches.isEmpty) return 0;

    final first = opponentMatches.first.outcome;
    if (first == MatchOutcome.tie) return 0;

    var streak = 0;
    for (final match in opponentMatches) {
      if (match.outcome == MatchOutcome.tie) break;
      if (match.outcome != first) break;
      streak += first == MatchOutcome.win ? 1 : -1;
    }
    return streak;
  }

  static List<RecentMatch> recentResultsForOpponent(
    Iterable<RecentMatch> matches,
    String opponentUid, {
    int limit = 3,
  }) {
    return _matchesForOpponent(matches, opponentUid).take(limit).toList();
  }

  static ChallengeRival buildRival(
    Iterable<RecentMatch> matches,
    String opponentUid,
  ) {
    final opponentMatches = _matchesForOpponent(matches, opponentUid);
    final latest = opponentMatches.first;
    return ChallengeRival(
      uid: opponentUid,
      displayName: latest.opponentLabel,
      lastPlayedAt: latest.playedAt,
      record: forOpponent(matches, opponentUid),
      lastOutcome: latest.outcome,
      currentStreak: currentStreak(matches, opponentUid),
      recentResults: opponentMatches.take(3).toList(),
    );
  }

  /// Unique rivals from challenge history, most recently played first.
  static List<ChallengeRival> recentRivals(
    Iterable<RecentMatch> matches, {
    int limit = 5,
  }) {
    return allRivals(matches).take(limit).toList();
  }

  /// All unique rivals, most recently played first.
  static List<ChallengeRival> allRivals(Iterable<RecentMatch> matches) {
    final challengeMatches = _challengeMatches(matches).toList();
    final byUid = <String, DateTime>{};

    for (final match in challengeMatches) {
      final uid = match.opponentUid!;
      final existing = byUid[uid];
      if (existing == null || match.playedAt.isAfter(existing)) {
        byUid[uid] = match.playedAt;
      }
    }

    final rivals = byUid.keys
        .map((uid) => buildRival(challengeMatches, uid))
        .toList()
      ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));

    return rivals;
  }

  /// Challenge matches newest-first (flat history list).
  static List<RecentMatch> chronologicalHistory(Iterable<RecentMatch> matches) {
    return _challengeMatches(matches).toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }
}
