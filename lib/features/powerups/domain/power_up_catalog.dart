import 'package:flutter/material.dart';

import '../../../core/theme/dot_clash_visuals.dart';
import 'power_up.dart';

/// Rewind/counter boosts — distinct from danger red and economy gold.
const Color kRiposteAccent = Color(0xFF9D6BFF);

abstract final class PowerUpCatalog {
  static const maxInventoryPerType = 99;

  static const prices = {
    PowerUpType.hold: 50,
    PowerUpType.riposte: 80,
    PowerUpType.extraTurns: 60,
    PowerUpType.domino: 120,
    PowerUpType.flow: 100,
  };

  static const labels = {
    PowerUpType.hold: 'Hold',
    PowerUpType.riposte: 'Riposte',
    PowerUpType.extraTurns: 'Extra Turns',
    PowerUpType.domino: 'Domino',
    PowerUpType.flow: 'Flow',
  };

  static const descriptions = {
    PowerUpType.hold: 'Skip their next turn.',
    PowerUpType.riposte: 'Undo their last full combo.',
    PowerUpType.extraTurns: 'Gain +3 turns in budgeted levels.',
    PowerUpType.domino: 'Next capture spreads to adjacent boxes.',
    PowerUpType.flow: 'Next chain auto-continues through friendly boxes.',
  };

  /// v1 rotating daily schedule (UTC day index % length).
  static const dailyBoostSchedule = [
    PowerUpType.hold,
    PowerUpType.riposte,
    PowerUpType.extraTurns,
  ];

  static const dailyBoostQuantity = 2;

  static PowerUpType todayDailyBoost([DateTime? utcNow]) {
    final now = utcNow ?? DateTime.now().toUtc();
    final days =
        DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    return dailyBoostSchedule[days % dailyBoostSchedule.length];
  }

  static int priceFor(PowerUpType type) => prices[type] ?? 0;

  /// Semantic UI accent per boost (in-match chips, shop, rescue sheets).
  static Color accentFor(PowerUpType type, DotClashVisuals v) => switch (type) {
        PowerUpType.hold => v.playerA,
        PowerUpType.riposte => kRiposteAccent,
        PowerUpType.extraTurns => v.gold,
        PowerUpType.domino => v.playerB,
        PowerUpType.flow => v.playerA,
      };
}
