import 'ai_preset.dart';

/// Pure Dart game model — zero Flutter dependencies.
/// This file is also shared with the Cloud Functions game-engine validator.

// ── Enums ──────────────────────────────────────────────────────────────────

enum GameMode {
  local, // 2 human players on the same device
  ai, // 1 human vs Practice (free) AI
  campaign, // campaign level vs AI
}

enum AiDifficulty { easy, medium, hard }

/// Persona for boss AI — changes the strategy bias on top of the base difficulty.
enum BossPersona { machine, trapper, collector }

// ── GameConfig ─────────────────────────────────────────────────────────────

class GameConfig {
  const GameConfig({
    required this.mode,
    this.rows = 5,
    this.cols = 5,
    this.aiDifficulty,
    this.campaignLevelId,
    this.bossPersona,
    this.disabledCells = const [],
    this.isDailyPuzzle = false,
    this.turnBudget,
  });

  final GameMode mode;
  final int rows;
  final int cols;
  final AiDifficulty? aiDifficulty;

  /// Set when mode == campaign. Used to track which level is being played.
  final String? campaignLevelId;

  /// Non-null on boss levels — adjusts AI aggression beyond base difficulty.
  final BossPersona? bossPersona;

  /// Box keys to mask out (World 5 irregular boards).
  final List<String> disabledCells;

  /// When true, settlement uses daily puzzle rewards (no life cost).
  final bool isDailyPuzzle;

  /// Human turn budget for campaign levels. Null = unlimited.
  final int? turnBudget;

  factory GameConfig.defaultLocal() => const GameConfig(mode: GameMode.local);

  factory GameConfig.vsAi(AiPreset preset) => GameConfig(
        mode: GameMode.ai,
        rows: preset.rows,
        cols: preset.cols,
        aiDifficulty: AiDifficulty.hard,
        disabledCells: preset.disabledCells,
      );

  factory GameConfig.campaign({
    required String levelId,
    required int gridSize,
    required AiDifficulty difficulty,
    BossPersona? persona,
    List<String> disabledCells = const [],
    int? turnBudget,
  }) =>
      GameConfig(
        mode: GameMode.campaign,
        rows: gridSize,
        cols: gridSize,
        aiDifficulty: difficulty,
        campaignLevelId: levelId,
        bossPersona: persona,
        disabledCells: disabledCells,
        turnBudget: turnBudget,
      );

  factory GameConfig.dailyPuzzle({
    required String levelId,
    required int gridSize,
    required AiDifficulty difficulty,
    BossPersona? persona,
    List<String> disabledCells = const [],
  }) =>
      GameConfig(
        mode: GameMode.campaign,
        rows: gridSize,
        cols: gridSize,
        aiDifficulty: difficulty,
        campaignLevelId: levelId,
        bossPersona: persona,
        disabledCells: disabledCells,
        isDailyPuzzle: true,
      );
}

// ── GameState ──────────────────────────────────────────────────────────────
//
// Edge keys:  "H_row_col"  (horizontal) or  "V_row_col"  (vertical)
// Box keys:   "row_col"
// Player IDs: "A" or "B" for local and AI games.

class GameState {
  const GameState({
    required this.rows,
    required this.cols,
    required this.drawnEdges,
    required this.edgeOwners,
    required this.claimedBoxes,
    required this.currentPlayerId,
    required this.scores,
    required this.moveHistory,
    required this.isOver,
    this.winnerId,
    this.playerIds = const ['A', 'B'],
    this.disabledCells = const {},
  });

  final int rows;
  final int cols;

  /// Box keys that are removed from the playfield (World 5 masked boards).
  /// These cells cannot be claimed and their boundary edges are not playable
  /// unless they border an active cell too.
  final Set<String> disabledCells;

  /// All edges that have been drawn, e.g. {"H_0_1", "V_2_3"}.
  final Set<String> drawnEdges;

  /// Edge key → player who drew it ([moveHistory] alone cannot reconstruct turns after timer passes).
  final Map<String, String> edgeOwners;

  /// Maps box key → player ID who claimed it.
  final Map<String, String> claimedBoxes;

  /// ID of the player whose turn it is.
  final String currentPlayerId;

  /// Score per player ID.
  final Map<String, int> scores;

  /// Ordered list of edge keys representing the move history.
  final List<String> moveHistory;

  final bool isOver;

  /// null = in-progress or tie; otherwise the winner's player ID.
  final String? winnerId;

  /// Ordered pair [playerA_id, playerB_id].
  final List<String> playerIds;

  // ── Computed ───────────────────────────────────────────────────────────────

  int get totalBoxes => (rows - 1) * (cols - 1) - disabledCells.length;
  int get claimedCount => claimedBoxes.length;
  bool get isTie => isOver && winnerId == null;
  String get opponentOf =>
      currentPlayerId == playerIds[0] ? playerIds[1] : playerIds[0];
  int scoreOf(String playerId) => scores[playerId] ?? 0;

  // ── Constructor helpers ────────────────────────────────────────────────────

  factory GameState.initial({
    int rows = 5,
    int cols = 5,
    List<String> playerIds = const ['A', 'B'],
    Set<String> disabledCells = const {},
  }) {
    return GameState(
      rows: rows,
      cols: cols,
      drawnEdges: const {},
      edgeOwners: const {},
      claimedBoxes: const {},
      currentPlayerId: playerIds[0],
      scores: {for (final id in playerIds) id: 0},
      moveHistory: const [],
      isOver: false,
      winnerId: null,
      playerIds: playerIds,
      disabledCells: disabledCells,
    );
  }

  // ── copyWith ───────────────────────────────────────────────────────────────

  GameState copyWith({
    int? rows,
    int? cols,
    Set<String>? drawnEdges,
    Map<String, String>? edgeOwners,
    Map<String, String>? claimedBoxes,
    String? currentPlayerId,
    Map<String, int>? scores,
    List<String>? moveHistory,
    bool? isOver,
    String? winnerId,
    bool clearWinner = false,
    List<String>? playerIds,
    Set<String>? disabledCells,
  }) {
    return GameState(
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      drawnEdges: drawnEdges ?? this.drawnEdges,
      edgeOwners: edgeOwners ?? this.edgeOwners,
      claimedBoxes: claimedBoxes ?? this.claimedBoxes,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      scores: scores ?? this.scores,
      moveHistory: moveHistory ?? this.moveHistory,
      isOver: isOver ?? this.isOver,
      winnerId: clearWinner ? null : (winnerId ?? this.winnerId),
      playerIds: playerIds ?? this.playerIds,
      disabledCells: disabledCells ?? this.disabledCells,
    );
  }

  // ── Firestore serialization ────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'disabledCells': disabledCells.toList(),
        'drawnEdges': drawnEdges.toList(),
        'edgeOwners': edgeOwners,
        'claimedBoxes': claimedBoxes,
        'currentPlayerId': currentPlayerId,
        'scores': scores,
        'moveHistory': moveHistory,
        'isOver': isOver,
        'winnerId': winnerId,
        'playerIds': playerIds,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final rawOwners = json['edgeOwners'];
    final edgeOwners = rawOwners == null
        ? const <String, String>{}
        : Map<String, String>.from(
            (rawOwners as Map)
                .map((k, v) => MapEntry(k as String, v as String)),
          );
    final rawDisabled = json['disabledCells'];
    final disabledCells = rawDisabled == null
        ? const <String>{}
        : Set<String>.from(rawDisabled as List);
    return GameState(
      rows: (json['rows'] as num).toInt(),
      cols: (json['cols'] as num).toInt(),
      disabledCells: disabledCells,
      drawnEdges: Set<String>.from(json['drawnEdges'] as List),
      edgeOwners: edgeOwners,
      claimedBoxes: Map<String, String>.from((json['claimedBoxes'] as Map)
          .map((k, v) => MapEntry(k as String, v as String))),
      currentPlayerId: json['currentPlayerId'] as String,
      scores: Map<String, int>.from((json['scores'] as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()))),
      moveHistory: List<String>.from(json['moveHistory'] as List),
      isOver: json['isOver'] as bool,
      winnerId: json['winnerId'] as String?,
      playerIds: List<String>.from(json['playerIds'] as List),
    );
  }

  @override
  String toString() =>
      'GameState(turn:$currentPlayerId, scores:$scores, moves:${moveHistory.length}, over:$isOver)';
}
