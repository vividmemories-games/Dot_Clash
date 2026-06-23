import 'package:dot_clash/features/challenge/domain/challenge_exceptions.dart';
import 'package:dot_clash/features/challenge/domain/challenge_room.dart';
import 'package:dot_clash/features/challenge/domain/challenge_status.dart';
import 'package:dot_clash/features/challenge/providers/challenge_game_provider.dart';
import 'package:dot_clash/features/challenge/providers/challenge_providers.dart';
import 'package:dot_clash/features/game/domain/models/game_state.dart';
import 'package:dot_clash/features/game/domain/rules/game_rules.dart';
import 'package:dot_clash/features/game/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _code = 'TEST01';
const _edge = 'H_0_0';

ChallengeRoom _activeRoom({required GameState gameState, int version = 0}) {
  return ChallengeRoom(
    code: _code,
    hostUid: 'host1',
    hostDisplayName: 'Alex',
    guestUid: 'guest1',
    guestDisplayName: 'Sam',
    status: ChallengeStatus.active,
    rows: 6,
    cols: 6,
    version: version,
    winnerUid: null,
    expiresAt: null,
    lastActivityAt: null,
    gameState: gameState,
    turnStartedAt: null,
  );
}

ProviderContainer _container({
  required GameState board,
  bool failSubmit = false,
  int version = 0,
}) {
  final room = _activeRoom(gameState: board, version: version);
  return ProviderContainer(
    overrides: [
      challengeRoomProvider.overrideWith(
        (ref, code) => Stream<ChallengeRoom?>.value(room),
      ),
      challengeMoveSubmitterProvider.overrideWith(
        (ref) => ({required String code, required String edgeKey}) async {
          if (failSubmit) {
            throw const ChallengeException('Not your turn');
          }
        },
      ),
      gameConfigProvider.overrideWith(
        (ref) => GameConfig.challenge(
          code: _code,
          myPlayerId: 'A',
          opponentDisplayName: 'Sam',
        ),
      ),
    ],
  );
}

void main() {
  group('ChallengeGameNotifier.makeMove', () {
    test('applies move optimistically before server ack', () async {
      final board = GameState.initial(rows: 6, cols: 6);
      final container = _container(board: board);
      addTearDown(container.dispose);

      final sub = container.listen(challengeGameProvider(_code), (_, __) {});
      addTearDown(sub.close);

      final notifier = container.read(challengeGameProvider(_code).notifier);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.moveHistory, isEmpty);

      await notifier.makeMove(_edge);

      expect(notifier.state.moveHistory, [_edge]);
      expect(notifier.state.drawnEdges, contains(_edge));
      expect(notifier.moveInFlight, isTrue);
    });

    test('rolls back to server gameState when submit fails', () async {
      final board = GameState.initial(rows: 6, cols: 6);
      final container = _container(board: board, failSubmit: true);
      addTearDown(container.dispose);

      final sub = container.listen(challengeGameProvider(_code), (_, __) {});
      addTearDown(sub.close);

      final notifier = container.read(challengeGameProvider(_code).notifier);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        notifier.makeMove(_edge),
        throwsA(isA<ChallengeException>()),
      );

      expect(notifier.state.moveHistory, isEmpty);
      expect(notifier.moveInFlight, isFalse);
    });

    test('reconciles to remote board when version advances', () async {
      final localBoard = GameState.initial(rows: 6, cols: 6);
      final remoteBoard = GameRules.applyMove(localBoard, _edge);
      final container = ProviderContainer(
        overrides: [
          challengeRoomProvider.overrideWith(
            (ref, code) => Stream<ChallengeRoom?>.value(
              _activeRoom(gameState: remoteBoard, version: 1),
            ),
          ),
          challengeMoveSubmitterProvider.overrideWith(
            (ref) => ({required String code, required String edgeKey}) async {},
          ),
          gameConfigProvider.overrideWith(
            (ref) => GameConfig.challenge(
              code: _code,
              myPlayerId: 'A',
              opponentDisplayName: 'Sam',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(challengeGameProvider(_code), (_, __) {});
      addTearDown(sub.close);

      final notifier = container.read(challengeGameProvider(_code).notifier);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.moveHistory, [_edge]);
      expect(notifier.moveInFlight, isFalse);
    });
  });

  group('ChallengeGameNotifier.onTurnTimedOut', () {
    test('submits random legal move on local timeout', () async {
      final board = GameState.initial(rows: 6, cols: 6);
      String? submittedEdge;
      final container = ProviderContainer(
        overrides: [
          challengeRoomProvider.overrideWith(
            (ref, code) => Stream<ChallengeRoom?>.value(
              _activeRoom(gameState: board),
            ),
          ),
          challengeMoveSubmitterProvider.overrideWith(
            (ref) => ({required String code, required String edgeKey}) async {
              submittedEdge = edgeKey;
            },
          ),
          gameConfigProvider.overrideWith(
            (ref) => GameConfig.challenge(
              code: _code,
              myPlayerId: 'A',
              opponentDisplayName: 'Sam',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(challengeGameProvider(_code), (_, __) {});
      addTearDown(sub.close);

      final notifier = container.read(challengeGameProvider(_code).notifier);
      await Future<void>.delayed(Duration.zero);

      await notifier.onTurnTimedOut();

      expect(submittedEdge, isNotNull);
      expect(notifier.state.moveHistory, [submittedEdge]);
    });

    test('no-op when not local player turn', () async {
      final board = GameState.initial(rows: 6, cols: 6).copyWith(
        currentPlayerId: 'B',
      );
      var submitCount = 0;
      final container = ProviderContainer(
        overrides: [
          challengeRoomProvider.overrideWith(
            (ref, code) => Stream<ChallengeRoom?>.value(
              _activeRoom(gameState: board),
            ),
          ),
          challengeMoveSubmitterProvider.overrideWith(
            (ref) => ({required String code, required String edgeKey}) async {
              submitCount++;
            },
          ),
          gameConfigProvider.overrideWith(
            (ref) => GameConfig.challenge(
              code: _code,
              myPlayerId: 'A',
              opponentDisplayName: 'Sam',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(challengeGameProvider(_code), (_, __) {});
      addTearDown(sub.close);

      final notifier = container.read(challengeGameProvider(_code).notifier);
      await Future<void>.delayed(Duration.zero);

      await notifier.onTurnTimedOut();

      expect(submitCount, 0);
    });
  });
}
