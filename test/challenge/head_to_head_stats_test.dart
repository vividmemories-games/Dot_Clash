import 'package:dot_clash/features/challenge/domain/head_to_head_stats.dart';
import 'package:dot_clash/features/home/domain/home_ui_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecentMatch _match({
    required String uid,
    required String name,
    required MatchOutcome outcome,
    required DateTime playedAt,
  }) {
    return RecentMatch(
      outcome: outcome,
      modeLabel: 'Challenge',
      opponentLabel: name,
      opponentUid: uid,
      playedAt: playedAt,
    );
  }

  group('HeadToHeadStats.forOpponent', () {
    test('aggregates wins losses ties for one uid', () {
      final matches = [
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 1),
        ),
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.loss,
          playedAt: DateTime(2026, 6, 2),
        ),
        _match(
          uid: 'rival2',
          name: 'Alex',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 3),
        ),
      ];

      final record = HeadToHeadStats.forOpponent(matches, 'rival1');
      expect(record.display, '1–1–0');
    });

    test('includes current outcome when provided', () {
      final record = HeadToHeadStats.forOpponent(
        const [],
        'rival1',
        includeCurrent: MatchOutcome.win,
      );
      expect(record.display, '1–0–0');
    });
  });

  group('HeadToHeadStats.currentStreak', () {
    test('counts consecutive wins from most recent', () {
      final matches = [
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 10),
        ),
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 9),
        ),
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.loss,
          playedAt: DateTime(2026, 6, 8),
        ),
      ];

      expect(HeadToHeadStats.currentStreak(matches, 'rival1'), 2);
    });

    test('counts consecutive losses as negative streak', () {
      final matches = [
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.loss,
          playedAt: DateTime(2026, 6, 10),
        ),
      ];

      expect(HeadToHeadStats.currentStreak(matches, 'rival1'), -1);
    });

    test('tie breaks streak', () {
      final matches = [
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.tie,
          playedAt: DateTime(2026, 6, 10),
        ),
      ];

      expect(HeadToHeadStats.currentStreak(matches, 'rival1'), 0);
    });
  });

  group('HeadToHeadStats.recentResultsForOpponent', () {
    test('returns newest results up to limit', () {
      final matches = [
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 1),
        ),
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.loss,
          playedAt: DateTime(2026, 6, 10),
        ),
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.tie,
          playedAt: DateTime(2026, 6, 5),
        ),
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 3),
        ),
      ];

      final recent =
          HeadToHeadStats.recentResultsForOpponent(matches, 'rival1', limit: 3);
      expect(recent.length, 3);
      expect(recent.first.outcome, MatchOutcome.loss);
      expect(recent.last.outcome, MatchOutcome.win);
    });
  });

  group('HeadToHeadStats.recentRivals', () {
    test('returns unique rivals most recent first with series record', () {
      final matches = [
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 1),
        ),
        _match(
          uid: 'rival2',
          name: 'Alex',
          outcome: MatchOutcome.loss,
          playedAt: DateTime(2026, 6, 10),
        ),
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.tie,
          playedAt: DateTime(2026, 6, 5),
        ),
      ];

      final rivals = HeadToHeadStats.recentRivals(matches, limit: 5);
      expect(rivals.length, 2);
      expect(rivals.first.uid, 'rival2');
      expect(rivals.first.displayName, 'Alex');
      expect(rivals.first.lastOutcome, MatchOutcome.loss);
      expect(rivals.first.rechallengeLabel, 'REVENGE');
      expect(rivals.last.record.display, '1–0–1');
      expect(rivals.last.rechallengeLabel, 'REMATCH');
    });

    test('ignores matches without opponentUid', () {
      final matches = [
        RecentMatch(
          outcome: MatchOutcome.win,
          modeLabel: 'Challenge',
          opponentLabel: 'Legacy',
          playedAt: DateTime(2026, 6, 1),
        ),
      ];
      expect(HeadToHeadStats.recentRivals(matches), isEmpty);
    });
  });

  group('HeadToHeadStats.allRivals', () {
    test('returns all rivals sorted by last played', () {
      final matches = [
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 1),
        ),
        _match(
          uid: 'rival2',
          name: 'Alex',
          outcome: MatchOutcome.loss,
          playedAt: DateTime(2026, 6, 10),
        ),
      ];

      final rivals = HeadToHeadStats.allRivals(matches);
      expect(rivals.length, 2);
      expect(rivals.first.uid, 'rival2');
    });
  });

  group('HeadToHeadStats.chronologicalHistory', () {
    test('returns challenge matches newest first', () {
      final matches = [
        _match(
          uid: 'rival1',
          name: 'Sam',
          outcome: MatchOutcome.win,
          playedAt: DateTime(2026, 6, 1),
        ),
        _match(
          uid: 'rival2',
          name: 'Alex',
          outcome: MatchOutcome.loss,
          playedAt: DateTime(2026, 6, 10),
        ),
        RecentMatch(
          outcome: MatchOutcome.win,
          modeLabel: 'Campaign',
          opponentLabel: 'AI',
          playedAt: DateTime(2026, 6, 11),
        ),
      ];

      final history = HeadToHeadStats.chronologicalHistory(matches);
      expect(history.length, 2);
      expect(history.first.opponentLabel, 'Alex');
    });
  });
}
