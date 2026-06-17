import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dot_clash/features/challenge/domain/challenge_board_preset.dart';
import 'package:dot_clash/features/challenge/domain/challenge_room.dart';
import 'package:dot_clash/features/challenge/domain/challenge_status.dart';
import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChallengeStatus', () {
    test('parse known values', () {
      expect(ChallengeStatus.parse('waiting'), ChallengeStatus.waiting);
      expect(ChallengeStatus.parse('active'), ChallengeStatus.active);
    });

    test('unknown maps to expired', () {
      expect(ChallengeStatus.parse('bogus'), ChallengeStatus.expired);
    });

    test('terminal statuses', () {
      expect(ChallengeStatus.finished.isTerminal, isTrue);
      expect(ChallengeStatus.waiting.isTerminal, isFalse);
    });
  });

  group('ChallengeRoom', () {
    test('opponentDisplayNameFor host and guest', () {
      const room = ChallengeRoom(
        code: 'ABC123',
        hostUid: 'host1',
        hostDisplayName: 'Alex',
        guestUid: 'guest1',
        guestDisplayName: 'Sam',
        status: ChallengeStatus.active,
        rows: 6,
        cols: 6,
        version: 1,
        winnerUid: null,
        expiresAt: null,
        lastActivityAt: null,
        gameState: null,
        turnStartedAt: null,
      );

      expect(room.opponentDisplayNameFor('host1'), 'Sam');
      expect(room.opponentDisplayNameFor('guest1'), 'Alex');
      expect(room.playerIdForUid('host1'), 'A');
      expect(room.playerIdForUid('guest1'), 'B');
      expect(room.opponentUidFor('host1'), 'guest1');
      expect(room.opponentUidFor('guest1'), 'host1');
      expect(room.isActive, isTrue);
      expect(room.hasPlayableBoard, isFalse);
    });

    test('hasPlayableBoard stays true when finished', () {
      const room = ChallengeRoom(
        code: 'ABC123',
        hostUid: 'host1',
        hostDisplayName: 'Alex',
        guestUid: 'guest1',
        guestDisplayName: 'Sam',
        status: ChallengeStatus.finished,
        rows: 6,
        cols: 6,
        version: 42,
        winnerUid: 'host1',
        expiresAt: null,
        lastActivityAt: null,
        gameState: null,
        turnStartedAt: null,
      );
      expect(room.isActive, isFalse);
      expect(room.hasPlayableBoard, isFalse);

      final withBoard = ChallengeRoom(
        code: room.code,
        hostUid: room.hostUid,
        hostDisplayName: room.hostDisplayName,
        guestUid: room.guestUid,
        guestDisplayName: room.guestDisplayName,
        status: ChallengeStatus.finished,
        rows: room.rows,
        cols: room.cols,
        version: room.version,
        winnerUid: room.winnerUid,
        expiresAt: room.expiresAt,
        lastActivityAt: room.lastActivityAt,
        gameState: GameState.initial(rows: 6, cols: 6),
        turnStartedAt: room.turnStartedAt,
      );
      expect(withBoard.hasPlayableBoard, isTrue);
    });

    test('fromFirestore reads board preset fields', () {
      final room = ChallengeRoom.fromFirestore(
        'ABC123',
        _FakeDocSnapshot({
          'hostUid': 'host1',
          'hostDisplayName': 'Alex',
          'guestUid': null,
          'status': 'waiting',
          'boardPresetId': 'challenge_blitz',
          'boardPresetName': 'Blitz',
          'rows': 4,
          'cols': 4,
          'version': 0,
        }),
      );

      expect(room.boardPresetId, 'challenge_blitz');
      expect(room.boardPresetName, 'Blitz');
      expect(room.rows, 4);
      expect(room.cols, 4);
      expect(room.boardPreset.name, 'Blitz');
    });

    test('fromFirestore defaults missing preset to Classic', () {
      final room = ChallengeRoom.fromFirestore(
        'ABC123',
        _FakeDocSnapshot({
          'hostUid': 'host1',
          'hostDisplayName': 'Alex',
          'status': 'waiting',
          'rows': 6,
          'cols': 6,
          'version': 0,
        }),
      );

      expect(room.boardPresetId, ChallengeBoardPreset.defaultPresetId);
      expect(room.boardPresetName, 'Classic');
    });
  });

  group('GameConfig.challenge', () {
    test('builds 6x6 challenge config', () {
      final config = GameConfig.challenge(
        code: 'abc123',
        myPlayerId: 'B',
        opponentDisplayName: 'Alex',
      );
      expect(config.mode, GameMode.challenge);
      expect(config.challengeCode, 'ABC123');
      expect(config.myPlayerId, 'B');
      expect(config.rows, 6);
      expect(config.cols, 6);
    });
  });
}

class _FakeDocSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot(this._data);

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
