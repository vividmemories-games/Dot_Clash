import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env/app_env.dart';
import '../../../shared/feedback/app_haptics.dart';
import '../../game/domain/models/game_state.dart';
import '../../game/domain/rules/game_rules.dart';
import '../../game/providers/game_provider.dart';
import '../domain/challenge_board_preset.dart';
import '../domain/challenge_exceptions.dart';
import '../domain/challenge_room.dart';
import 'challenge_providers.dart';

typedef ChallengeMoveSubmitter = Future<void> Function({
  required String code,
  required String edgeKey,
});

final challengeMoveSubmitterProvider = Provider<ChallengeMoveSubmitter>((ref) {
  final repo = ref.read(challengeRepositoryProvider);
  return ({required String code, required String edgeKey}) =>
      repo.submitChallengeMove(code: code, edgeKey: edgeKey);
});

/// Server-synced board state for a live challenge match.
final challengeGameProvider = StateNotifierProvider.autoDispose
    .family<ChallengeGameNotifier, GameState, String>((ref, code) {
  return ChallengeGameNotifier(ref, code: code.trim().toUpperCase());
});

/// Countdown derived from Firestore `turnStartedAt` (server enforces timeout).
final challengeTurnTimerProvider = StateNotifierProvider.autoDispose
    .family<ChallengeTurnTimerNotifier, int, String>((ref, code) {
  final normalized = code.trim().toUpperCase();
  final notifier = ChallengeTurnTimerNotifier();
  ref.listen(challengeRoomProvider(normalized), (_, next) {
    final started = next.valueOrNull?.turnStartedAt;
    if (started != null) {
      notifier.sync(started);
    }
  }, fireImmediately: true);
  ref.onDispose(notifier.stop);
  return notifier;
});

class ChallengeTurnTimerNotifier extends StateNotifier<int> {
  ChallengeTurnTimerNotifier() : super(AppEnv.turnTimerSeconds);

  Timer? _timer;
  DateTime? _turnStartedAt;

  void sync(DateTime turnStartedAt) {
    if (!mounted) return;
    if (_turnStartedAt == turnStartedAt) return;
    _turnStartedAt = turnStartedAt;
    _recalc();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _recalc());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _recalc() {
    if (!mounted) return;
    final started = _turnStartedAt;
    if (started == null) return;
    final elapsed = DateTime.now().difference(started).inSeconds;
    state = (AppEnv.turnTimerSeconds - elapsed).clamp(0, AppEnv.turnTimerSeconds);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class ChallengeGameNotifier extends StateNotifier<GameState> {
  ChallengeGameNotifier(this._ref, {required this.code})
      : super(_seedState(_ref, code)) {
    _roomSub = _ref.listen<AsyncValue<ChallengeRoom?>>(
      challengeRoomProvider(code),
      (_, next) {
        final room = next.valueOrNull;
        if (room?.gameState != null) {
          _applyRemoteRoom(room!);
        }
      },
      fireImmediately: true,
    );
  }

  static GameState _seedState(Ref ref, String code) {
    final room = ref.read(challengeRoomProvider(code)).valueOrNull;
    if (room?.gameState != null) return room!.gameState!;
    final preset = room?.boardPreset ?? ChallengeBoardPreset.defaultPreset;
    return GameState.initial(
      rows: room?.rows ?? preset.rows,
      cols: room?.cols ?? preset.cols,
      disabledCells: preset.disabledCells.toSet(),
    );
  }

  final Ref _ref;
  final String code;
  late final ProviderSubscription<AsyncValue<ChallengeRoom?>> _roomSub;

  int _lastVersion = -1;
  bool _moveInFlight = false;
  static final _rng = Random();

  String get _myPlayerId => _ref.read(gameConfigProvider).myPlayerId ?? 'A';

  bool get moveInFlight => _moveInFlight;

  Future<void> makeMove(String edgeKey) async {
    if (_moveInFlight) return;
    if (!GameRules.isLegalMove(state, edgeKey)) return;
    if (state.currentPlayerId != _myPlayerId) return;
    if (state.isOver) return;

    final preMoveState = state;
    _moveInFlight = true;
    _ref.read(opponentLastEdgeProvider.notifier).state = null;
    state = GameRules.applyMove(state, edgeKey);

    try {
      await _ref.read(challengeMoveSubmitterProvider)(
            code: code,
            edgeKey: edgeKey,
          );
    } on ChallengeException {
      final serverState =
          _ref.read(challengeRoomProvider(code)).valueOrNull?.gameState;
      state = serverState ?? preMoveState;
      _moveInFlight = false;
      rethrow;
    }
  }

  /// Client backup when server scheduler is slow — same callable as a human tap.
  Future<void> onTurnTimedOut() async {
    if (_moveInFlight) return;
    if (state.isOver) return;
    if (state.currentPlayerId != _myPlayerId) return;

    final legalMoves = GameRules.legalMoves(state);
    if (legalMoves.isEmpty) return;

    final edgeKey = legalMoves[_rng.nextInt(legalMoves.length)];
    await makeMove(edgeKey);
  }

  void _applyRemoteRoom(ChallengeRoom room) {
    final remote = room.gameState;
    if (remote == null) return;
    if (room.version < _lastVersion) return;
    if (room.version == _lastVersion && state.moveHistory.isNotEmpty) return;

    if (remote.moveHistory.length > state.moveHistory.length) {
      final lastEdge = remote.moveHistory.last;
      final owner = remote.edgeOwners[lastEdge];
      if (owner != null && owner != _myPlayerId) {
        _ref.read(opponentLastEdgeProvider.notifier).state = lastEdge;
        AppHaptics.lightImpact();
      } else {
        _ref.read(opponentLastEdgeProvider.notifier).state = null;
      }
    }

    _lastVersion = room.version;
    state = remote;
    _moveInFlight = false;
  }

  @override
  void dispose() {
    _roomSub.close();
    super.dispose();
  }
}
