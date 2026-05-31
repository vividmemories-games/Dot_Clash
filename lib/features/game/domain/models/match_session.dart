import '../../../powerups/domain/power_up.dart';

/// Per-match session state (turn budget, boosts used this game).
class MatchSession {
  const MatchSession({
    this.turnBudget,
    this.turnsRemaining,
    this.skipAiTurnsRemaining = 0,
    this.powerUpsUsed = const {},
    this.holdUsed = false,
    this.riposteUsed = false,
    this.extraTurnsUsed = false,
    this.aiSegmentStartMoveIndex = 0,
    this.pendingRiposteOffer = false,
    this.outOfTurnsPending = false,
  });

  final int? turnBudget;
  final int? turnsRemaining;
  final int skipAiTurnsRemaining;
  final Set<PowerUpType> powerUpsUsed;
  final bool holdUsed;
  final bool riposteUsed;
  final bool extraTurnsUsed;
  final int aiSegmentStartMoveIndex;
  final bool pendingRiposteOffer;
  final bool outOfTurnsPending;

  bool get hasTurnBudget => turnBudget != null;

  MatchSession copyWith({
    int? turnBudget,
    int? turnsRemaining,
    int? skipAiTurnsRemaining,
    Set<PowerUpType>? powerUpsUsed,
    bool? holdUsed,
    bool? riposteUsed,
    bool? extraTurnsUsed,
    int? aiSegmentStartMoveIndex,
    bool? pendingRiposteOffer,
    bool? outOfTurnsPending,
  }) {
    return MatchSession(
      turnBudget: turnBudget ?? this.turnBudget,
      turnsRemaining: turnsRemaining ?? this.turnsRemaining,
      skipAiTurnsRemaining: skipAiTurnsRemaining ?? this.skipAiTurnsRemaining,
      powerUpsUsed: powerUpsUsed ?? this.powerUpsUsed,
      holdUsed: holdUsed ?? this.holdUsed,
      riposteUsed: riposteUsed ?? this.riposteUsed,
      extraTurnsUsed: extraTurnsUsed ?? this.extraTurnsUsed,
      aiSegmentStartMoveIndex:
          aiSegmentStartMoveIndex ?? this.aiSegmentStartMoveIndex,
      pendingRiposteOffer: pendingRiposteOffer ?? this.pendingRiposteOffer,
      outOfTurnsPending: outOfTurnsPending ?? this.outOfTurnsPending,
    );
  }

  MatchSession grantExtraTurns(int amount) {
    if (turnsRemaining == null) return this;
    return copyWith(turnsRemaining: turnsRemaining! + amount);
  }
}
