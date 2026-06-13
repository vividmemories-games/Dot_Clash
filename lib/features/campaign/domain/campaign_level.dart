import '../../game/domain/models/game_state.dart';

// ── Star objectives ──────────────────────────────────────────────────────────

enum ObjectiveType { win, margin, maxMoves, preventChain, maxAiBoxes, none }

class StarObjective {
  const StarObjective({
    required this.type,
    this.value,
    this.min,
  });

  final ObjectiveType type;
  final int? value;
  final int? min;

  factory StarObjective.win() => const StarObjective(type: ObjectiveType.win);

  factory StarObjective.margin(int minMargin) =>
      StarObjective(type: ObjectiveType.margin, min: minMargin);

  factory StarObjective.maxMoves(int maxMoves) =>
      StarObjective(type: ObjectiveType.maxMoves, value: maxMoves);

  factory StarObjective.preventChain() =>
      const StarObjective(type: ObjectiveType.preventChain);

  factory StarObjective.maxAiBoxes(int maxBoxes) =>
      StarObjective(type: ObjectiveType.maxAiBoxes, value: maxBoxes);

  factory StarObjective.fromJson(Map<String, dynamic> json) {
    final type = switch (json['type'] as String? ?? 'win') {
      'margin' => ObjectiveType.margin,
      'maxMoves' || 'maxTurns' => ObjectiveType.maxMoves,
      'preventChain' => ObjectiveType.preventChain,
      'maxAiBoxes' => ObjectiveType.maxAiBoxes,
      _ => ObjectiveType.win,
    };
    return StarObjective(
      type: type,
      value: (json['value'] as num?)?.toInt(),
      min: (json['min'] as num?)?.toInt(),
    );
  }

  String get description => switch (type) {
        ObjectiveType.win => 'Win the match',
        ObjectiveType.margin => 'Win by ${min ?? 1}+ boxes',
        ObjectiveType.maxMoves => 'Finish in ≤${value ?? 0} turns',
        ObjectiveType.preventChain => 'No rival chain of 3+ boxes',
        ObjectiveType.maxAiBoxes => 'Rival gets ≤${value ?? 0} boxes',
        ObjectiveType.none => '',
      };
}

// ── Campaign level definition ─────────────────────────────────────────────────

class CampaignLevel {
  const CampaignLevel({
    required this.id,
    required this.worldId,
    required this.index,
    required this.title,
    required this.gridSize,
    required this.aiDifficulty,
    required this.isBoss,
    required this.star1,
    required this.star2,
    required this.star3,
    this.bossPersona,
    this.bossName,
    this.coinReward = 15,
    this.xpReward = 20,
    this.disabledCells = const [],
    this.turnBudget,
    this.powerUpRewards = const {},
  });

  final String id;
  final int worldId;
  final int index;
  final String title;

  /// Dot rows/cols on the board (e.g. 5 → 5×5 dots, 4×4 boxes).
  final int gridSize;

  /// Label matching the on-screen dot grid (what players count).
  String get gridDotsLabel => '$gridSize×$gridSize';

  /// Playable box count (one fewer dot per side).
  String get gridBoxesLabel => '${gridSize - 1}×${gridSize - 1}';
  final AiDifficulty aiDifficulty;
  final bool isBoss;

  final StarObjective star1;
  final StarObjective star2;
  final StarObjective star3;

  /// Only set on boss levels.
  final String? bossPersona;
  final String? bossName;

  final int coinReward;
  final int xpReward;

  /// List of box keys ("row_col") to exclude from the playfield (World 5 masking).
  final List<String> disabledCells;

  /// When set, human must win before turns run out. Null = unlimited.
  final int? turnBudget;

  /// Boss / level power-up grants on win, keyed by [PowerUpType.id].
  final Map<String, int> powerUpRewards;

  /// Effective turn budget including calculator fallback.
  int? get effectiveTurnBudget {
    if (turnBudget != null) return turnBudget;
    // Import deferred via static helper in router/content — set at play time.
    return null;
  }

  BossPersona? get parsedPersona => switch (bossPersona) {
        'machine' => BossPersona.machine,
        'trapper' => BossPersona.trapper,
        'collector' => BossPersona.collector,
        _ => null,
      };

  factory CampaignLevel.fromJson(Map<String, dynamic> json) {
    StarObjective parseObjective(dynamic raw) {
      if (raw == null) return StarObjective.win();
      if (raw is Map<String, dynamic>) return StarObjective.fromJson(raw);
      return StarObjective.win();
    }

    final objectives = json['objectives'] as Map<String, dynamic>? ?? {};

    return CampaignLevel(
      id: json['id'] as String,
      worldId: (json['worldId'] as num).toInt(),
      index: (json['index'] as num).toInt(),
      title: json['title'] as String,
      gridSize: (json['gridSize'] as num).toInt(),
      aiDifficulty:
          _parseDifficulty(json['aiDifficulty'] as String? ?? 'medium'),
      isBoss: json['isBoss'] as bool? ?? false,
      star1: parseObjective(objectives['star1']),
      star2: parseObjective(objectives['star2']),
      star3: parseObjective(objectives['star3']),
      bossPersona: json['persona'] as String?,
      bossName: json['bossName'] as String?,
      coinReward: (json['rewards']?['coins'] as num?)?.toInt() ?? 15,
      xpReward: (json['rewards']?['xp'] as num?)?.toInt() ?? 20,
      disabledCells: (json['disabledCells'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      turnBudget: (json['turnBudget'] as num?)?.toInt(),
      powerUpRewards: _parsePowerUpRewards(json['powerUpRewards']),
    );
  }

  static Map<String, int> _parsePowerUpRewards(dynamic raw) {
    if (raw is! Map) return const {};
    return Map<String, int>.from(
      raw.map((k, v) => MapEntry(k as String, (v as num).toInt())),
    );
  }

  static Map<String, int> defaultBossPowerUpRewards(CampaignLevel level) {
    if (!level.isBoss) return const {};
    if (level.worldId >= 4 || level.index >= 18) {
      return const {'hold': 2, 'riposte': 2, 'extraTurns': 1};
    }
    if (level.index >= 15) {
      return const {'hold': 1, 'riposte': 1, 'extraTurns': 1};
    }
    return const {'hold': 1, 'riposte': 1};
  }

  static AiDifficulty _parseDifficulty(String value) => switch (value) {
        'easy' => AiDifficulty.easy,
        'hard' => AiDifficulty.hard,
        _ => AiDifficulty.medium,
      };
}
