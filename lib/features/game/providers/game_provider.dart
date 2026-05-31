import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env/app_env.dart';
import '../../ai/ai_player.dart';
import '../../campaign/domain/campaign_move_metrics.dart';
import '../../powerups/domain/power_up.dart';
import '../domain/models/game_state.dart';
import '../domain/models/match_session.dart';
import '../domain/rules/game_rules.dart';
import 'match_session_provider.dart';

final turnTimerProvider =
    StateNotifierProvider.autoDispose<TurnTimerNotifier, int>(
  (_) => TurnTimerNotifier(),
);

class TurnTimerNotifier extends StateNotifier<int> {
  TurnTimerNotifier() : super(AppEnv.turnTimerSeconds);

  Timer? _timer;

  void reset() {
    _timer?.cancel();
    state = AppEnv.turnTimerSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) {
        state--;
      } else {
        _timer?.cancel();
      }
    });
  }

  void stop() => _timer?.cancel();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final gameConfigProvider = StateProvider<GameConfig>(
  (_) => GameConfig.defaultLocal(),
);

final gameProvider =
    StateNotifierProvider.autoDispose<GameNotifier, GameState>((ref) {
  final config = ref.watch(gameConfigProvider);
  return GameNotifier(ref, config);
});

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier(this._ref, this._config)
      : super(GameState.initial(
          rows: _config.rows,
          cols: _config.cols,
          disabledCells: Set<String>.from(_config.disabledCells),
        )) {
    if (_config.turnBudget != null) {
      _ref.read(matchSessionProvider.notifier).init(
            turnBudget: _config.turnBudget,
          );
    }
    _maybeScheduleAiMove();
  }

  final Ref _ref;
  final GameConfig _config;
  final Random _rng = Random();

  static const _humanId = 'A';
  static const _aiId = 'B';

  MatchSession get _session => _ref.read(matchSessionProvider);

  void _setSession(MatchSession session) {
    _ref.read(matchSessionProvider.notifier).update(session);
  }

  void makeMove(String edgeKey) {
    if (!GameRules.isLegalMove(state, edgeKey)) return;
    if (_session.outOfTurnsPending) return;

    final wasHumanTurn = state.currentPlayerId == _humanId;
    state = GameRules.applyMove(state, edgeKey);
    _ref.read(turnTimerProvider.notifier).reset();

    if (wasHumanTurn && state.currentPlayerId != _humanId) {
      _onHumanControlPeriodEnded();
    } else if (!wasHumanTurn && state.currentPlayerId == _humanId) {
      _checkRiposteOffer();
    }

    _maybeScheduleAiMove();
  }

  void _onHumanControlPeriodEnded() {
    var session = _session;
    if (!session.hasTurnBudget || state.isOver) return;

    final remaining = (session.turnsRemaining ?? 0) - 1;
    if (remaining <= 0) {
      _setSession(session.copyWith(turnsRemaining: 0, outOfTurnsPending: true));
      return;
    }
    _setSession(session.copyWith(turnsRemaining: remaining));
  }

  void finalizeOutOfTurns() {
    _resolveOutOfTurns();
  }

  void _resolveOutOfTurns() {
    final humanScore = state.scoreOf(_humanId);
    final aiScore = state.scoreOf(_aiId);
    if (humanScore > aiScore) {
      state = state.copyWith(isOver: true, winnerId: _humanId);
    } else {
      state = state.copyWith(
        isOver: true,
        winnerId: humanScore > aiScore ? _humanId : (humanScore < aiScore ? _aiId : null),
        clearWinner: humanScore == aiScore,
      );
    }
    _setSession(_session.copyWith(outOfTurnsPending: false, turnsRemaining: 0));
  }

  void _checkRiposteOffer() {
    if (state.isOver) return;
    final aiChain = CampaignMoveMetrics.aiMaxChainBoxes(state, _humanId);
    if (aiChain >= 3 && !_session.riposteUsed) {
      _setSession(_session.copyWith(pendingRiposteOffer: true));
    }
  }

  void clearRiposteOffer() {
    _setSession(_session.copyWith(pendingRiposteOffer: false));
  }

  Future<bool> useHold() async {
    final session = _session;
    if (session.holdUsed || state.isOver || state.currentPlayerId != _humanId) {
      return false;
    }
    _setSession(session.copyWith(
      holdUsed: true,
      skipAiTurnsRemaining: session.skipAiTurnsRemaining + 1,
      powerUpsUsed: {...session.powerUpsUsed, PowerUpType.hold},
    ));
    return true;
  }

  Future<bool> useRiposte() async {
    final session = _session;
    if (session.riposteUsed || state.moveHistory.isEmpty) return false;

    final rewindTo = CampaignMoveMetrics.lastAiControlPeriodStartMoveIndex(
      state,
      _humanId,
    );
    if (rewindTo == null) return false;

    var rebuilt = GameState.initial(
      rows: state.rows,
      cols: state.cols,
      disabledCells: state.disabledCells,
    );
    for (var i = 0; i < rewindTo; i++) {
      rebuilt = GameRules.applyMove(rebuilt, state.moveHistory[i]);
    }
    state = rebuilt.copyWith(currentPlayerId: _humanId);

    var updatedSession = session.copyWith(
      riposteUsed: true,
      pendingRiposteOffer: false,
      powerUpsUsed: {...session.powerUpsUsed, PowerUpType.riposte},
    );
    if (session.hasTurnBudget && session.turnsRemaining != null) {
      updatedSession = updatedSession.copyWith(
        turnsRemaining: session.turnsRemaining! + 1,
      );
    }

    _ref.read(turnTimerProvider.notifier).reset();
    _setSession(updatedSession);
    return true;
  }

  void addTurnsFromBoost(int amount) {
    final session = _session;
    if (!session.hasTurnBudget) return;
    _setSession(session.grantExtraTurns(amount).copyWith(
      extraTurnsUsed: true,
      outOfTurnsPending: false,
      powerUpsUsed: {...session.powerUpsUsed, PowerUpType.extraTurns},
    ));
  }

  void undo() {
    if (state.moveHistory.isEmpty) return;
    var target = state;
    target = GameRules.undo(target);
    if ((_config.mode == GameMode.ai || _config.mode == GameMode.campaign) &&
        target.currentPlayerId != _humanId) {
      target = GameRules.undo(target);
    }
    state = target;
    _ref.read(turnTimerProvider.notifier).reset();
  }

  void newGame({int? rows, int? cols}) {
    state = GameState.initial(
      rows: rows ?? _config.rows,
      cols: cols ?? _config.cols,
      disabledCells: Set<String>.from(_config.disabledCells),
    );
    _ref.read(matchSessionProvider.notifier).init(turnBudget: _config.turnBudget);
    _ref.read(turnTimerProvider.notifier).reset();
    _maybeScheduleAiMove();
  }

  void onTurnTimedOut() {
    if (state.isOver) return;

    final timedOutPlayer = state.currentPlayerId;
    final legalMoves = GameRules.legalMoves(state);
    if (legalMoves.isNotEmpty) {
      final randomMove = legalMoves[_rng.nextInt(legalMoves.length)];
      state = GameRules.applyMove(state, randomMove);
    }

    if (!state.isOver) {
      final nextPlayer = timedOutPlayer == state.playerIds[0]
          ? state.playerIds[1]
          : state.playerIds[0];
      state = state.copyWith(currentPlayerId: nextPlayer);
    }
    if (timedOutPlayer == _humanId && state.currentPlayerId != _humanId) {
      _onHumanControlPeriodEnded();
    }
    _ref.read(turnTimerProvider.notifier).reset();
    _maybeScheduleAiMove();
  }

  void _maybeScheduleAiMove() {
    if (_config.mode != GameMode.ai && _config.mode != GameMode.campaign) {
      return;
    }
    if (state.isOver) return;
    if (_session.outOfTurnsPending) return;

    final session = _session;
    if (session.skipAiTurnsRemaining > 0 && state.currentPlayerId == _aiId) {
      _setSession(session.copyWith(
        skipAiTurnsRemaining: session.skipAiTurnsRemaining - 1,
      ));
      state = state.copyWith(currentPlayerId: _humanId);
      _ref.read(turnTimerProvider.notifier).reset();
      return;
    }

    if (state.currentPlayerId == _humanId) return;

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (state.isOver || state.currentPlayerId != _aiId) return;

      final move = AiPlayer.pickMove(
        state,
        _config.aiDifficulty ?? AiDifficulty.medium,
        persona: _config.bossPersona,
      );

      if (move != null) makeMove(move);
    });
  }
}

extension _ConfigPlayerIds on GameConfig {
  List<String> get playerIds => ['A', 'B'];
}
