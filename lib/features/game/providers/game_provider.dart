import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env/app_env.dart';
import '../../../shared/feedback/app_haptics.dart';
import '../../ai/ai_player.dart';
import '../../campaign/domain/campaign_move_metrics.dart';
import '../../powerups/domain/power_up.dart';
import '../../settings/providers/settings_provider.dart';
import '../../tutorial/providers/coach_tour_provider.dart';
import '../domain/ai_pacing.dart';
import '../domain/models/game_state.dart';
import '../domain/models/match_session.dart';
import '../domain/rules/game_rules.dart';
import 'match_session_provider.dart';

/// Edge key of the opponent's most recent move (for board highlight).
final opponentLastEdgeProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// False briefly when the human regains control so the board can be read.
final humanTurnReadyProvider = StateProvider.autoDispose<bool>((ref) => true);

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
    _startTicking();
  }

  /// Restarts the countdown without resetting [state] (e.g. after app foreground).
  void resume() {
    _timer?.cancel();
    if (state <= 0) return;
    _startTicking();
  }

  void _startTicking() {
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

  int _aiScheduleGeneration = 0;
  int _handoffGeneration = 0;

  bool get _isVsAi =>
      _config.mode == GameMode.ai || _config.mode == GameMode.campaign;

  MatchSession get _session => _ref.read(matchSessionProvider);

  void _setSession(MatchSession session) {
    _ref.read(matchSessionProvider.notifier).update(session);
  }

  void makeMove(String edgeKey) {
    if (!GameRules.isLegalMove(state, edgeKey)) return;
    if (_session.outOfTurnsPending) return;

    final moverId = state.currentPlayerId;
    final wasHumanTurn = moverId == _humanId;

    if (moverId == _aiId) {
      _ref.read(opponentLastEdgeProvider.notifier).state = edgeKey;
      AppHaptics.lightImpact();
    } else {
      _ref.read(opponentLastEdgeProvider.notifier).state = null;
    }

    state = GameRules.applyMove(state, edgeKey);
    _ref.read(turnTimerProvider.notifier).reset();

    if (wasHumanTurn && state.currentPlayerId != _humanId) {
      _onHumanControlPeriodEnded();
    } else if (!wasHumanTurn && state.currentPlayerId == _humanId) {
      _checkRiposteOffer();
    }

    _onTurnAdvanced(wasHumanTurn: wasHumanTurn);
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
    final lastChain =
        CampaignMoveMetrics.lastAiSegmentBoxCount(state, _humanId);
    if (lastChain >= 3 && !_session.riposteUsed) {
      _setSession(_session.copyWith(pendingRiposteOffer: true));
    }
  }

  /// Pauses turn timer and cancels scheduled AI / handoff while app is backgrounded.
  void onAppPaused() {
    _ref.read(turnTimerProvider.notifier).stop();
    _cancelAiSchedule();
    _cancelHandoff();
  }

  /// Restores timer and AI scheduling after returning to foreground.
  void onAppResumed() {
    if (state.isOver || _session.outOfTurnsPending) return;

    final showTimer = _ref.read(settingsProvider).showTimer;
    final tourPaused = _ref.read(matchCoachTourProvider).matchPaused;
    if (showTimer && !tourPaused && state.currentPlayerId == _humanId) {
      final secondsLeft = _ref.read(turnTimerProvider);
      if (secondsLeft <= 0) {
        onTurnTimedOut();
      } else {
        _ref.read(turnTimerProvider.notifier).resume();
      }
    }
    _maybeScheduleAiMove();
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

  /// Rolls back [useHold] when server inventory consume fails after local apply.
  void revertHold() {
    final session = _session;
    if (!session.holdUsed || session.skipAiTurnsRemaining <= 0) return;
    final powerUpsUsed = Set<PowerUpType>.from(session.powerUpsUsed)
      ..remove(PowerUpType.hold);
    _setSession(session.copyWith(
      holdUsed: false,
      skipAiTurnsRemaining: session.skipAiTurnsRemaining - 1,
      powerUpsUsed: powerUpsUsed,
    ));
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

    _cancelAiSchedule();
    _ref.read(opponentLastEdgeProvider.notifier).state = null;
    _ref.read(humanTurnReadyProvider.notifier).state = true;

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
    _cancelAiSchedule();
    _ref.read(opponentLastEdgeProvider.notifier).state =
        _lastOpponentEdgeFromHistory();
    _ref.read(humanTurnReadyProvider.notifier).state = true;
    if (_isVsAi && !state.isOver && state.currentPlayerId == _aiId) {
      _scheduleAiMove(delayMs: AiPacing.thinkBeforeFirstMs);
    }
  }

  String? _lastOpponentEdgeFromHistory() {
    for (var i = state.moveHistory.length - 1; i >= 0; i--) {
      final edge = state.moveHistory[i];
      if (state.edgeOwners[edge] == _aiId) return edge;
    }
    return null;
  }

  void newGame({int? rows, int? cols}) {
    state = GameState.initial(
      rows: rows ?? _config.rows,
      cols: cols ?? _config.cols,
      disabledCells: Set<String>.from(_config.disabledCells),
    );
    _ref.read(matchSessionProvider.notifier).init(turnBudget: _config.turnBudget);
    _ref.read(turnTimerProvider.notifier).reset();
    _cancelAiSchedule();
    _ref.read(opponentLastEdgeProvider.notifier).state = null;
    _ref.read(humanTurnReadyProvider.notifier).state = true;
    _maybeScheduleAiMove();
  }

  void onTurnTimedOut() {
    if (state.isOver) return;

    final timedOutPlayer = state.currentPlayerId;
    final wasHuman = timedOutPlayer == _humanId;
    final legalMoves = GameRules.legalMoves(state);
    if (legalMoves.isNotEmpty) {
      final randomMove = legalMoves[_rng.nextInt(legalMoves.length)];
      if (timedOutPlayer == _aiId) {
        _ref.read(opponentLastEdgeProvider.notifier).state = randomMove;
      } else {
        _ref.read(opponentLastEdgeProvider.notifier).state = null;
      }
      state = GameRules.applyMove(state, randomMove);
    }

    if (!state.isOver) {
      final nextPlayer = timedOutPlayer == state.playerIds[0]
          ? state.playerIds[1]
          : state.playerIds[0];
      state = state.copyWith(currentPlayerId: nextPlayer);
    }
    if (wasHuman && state.currentPlayerId != _humanId) {
      _onHumanControlPeriodEnded();
    }
    _ref.read(turnTimerProvider.notifier).reset();
    _onTurnAdvanced(wasHumanTurn: wasHuman);
  }

  void _cancelAiSchedule() => _aiScheduleGeneration++;

  void _cancelHandoff() {
    _handoffGeneration++;
    _ref.read(humanTurnReadyProvider.notifier).state = true;
  }

  void _onTurnAdvanced({required bool wasHumanTurn}) {
    _cancelAiSchedule();

    if (!_isVsAi || state.isOver || _session.outOfTurnsPending) return;

    if (state.currentPlayerId == _aiId) {
      final delayMs = wasHumanTurn
          ? AiPacing.thinkBeforeFirstMs
          : AiPacing.afterAiMoveMs;
      _scheduleAiMove(delayMs: delayMs);
      return;
    }

    if (!wasHumanTurn && state.currentPlayerId == _humanId) {
      _startHumanHandoffPause();
    }
  }

  void _startHumanHandoffPause() {
    _cancelHandoff();
    _ref.read(humanTurnReadyProvider.notifier).state = false;
    final generation = ++_handoffGeneration;
    Future.delayed(
      const Duration(milliseconds: AiPacing.handoffToHumanMs),
      () {
        if (!mounted || generation != _handoffGeneration) return;
        _ref.read(humanTurnReadyProvider.notifier).state = true;
      },
    );
  }

  void _maybeScheduleAiMove() {
    if (!_isVsAi || state.isOver || _session.outOfTurnsPending) return;

    final session = _session;
    if (session.skipAiTurnsRemaining > 0 && state.currentPlayerId == _aiId) {
      _setSession(session.copyWith(
        skipAiTurnsRemaining: session.skipAiTurnsRemaining - 1,
      ));
      state = state.copyWith(currentPlayerId: _humanId);
      _ref.read(turnTimerProvider.notifier).reset();
      _ref.read(opponentLastEdgeProvider.notifier).state = null;
      _startHumanHandoffPause();
      return;
    }

    if (state.currentPlayerId == _aiId) {
      _scheduleAiMove(delayMs: AiPacing.thinkBeforeFirstMs);
    }
  }

  void _scheduleAiMove({required int delayMs}) {
    if (!_isVsAi) return;

    final generation = ++_aiScheduleGeneration;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted || generation != _aiScheduleGeneration) return;
      if (state.isOver || _session.outOfTurnsPending) return;
      if (state.currentPlayerId != _aiId) return;

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
