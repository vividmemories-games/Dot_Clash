/**
 * Pure Dots & Boxes rules engine — port of lib/features/game/domain/rules/game_rules.dart.
 * Keep in sync with test/game/rules_test.dart vectors.
 */

export interface GameStateJson {
  rows: number;
  cols: number;
  disabledCells?: string[];
  drawnEdges: string[];
  edgeOwners: Record<string, string>;
  claimedBoxes: Record<string, string>;
  currentPlayerId: string;
  scores: Record<string, number>;
  moveHistory: string[];
  isOver: boolean;
  winnerId: string | null;
  playerIds: string[];
}

export class GameState {
  readonly rows: number;
  readonly cols: number;
  readonly disabledCells: Set<string>;
  readonly drawnEdges: Set<string>;
  readonly edgeOwners: Record<string, string>;
  readonly claimedBoxes: Record<string, string>;
  readonly currentPlayerId: string;
  readonly scores: Record<string, number>;
  readonly moveHistory: string[];
  readonly isOver: boolean;
  readonly winnerId: string | null;
  readonly playerIds: string[];

  constructor(opts: {
    rows: number;
    cols: number;
    disabledCells?: Set<string>;
    drawnEdges: Set<string>;
    edgeOwners: Record<string, string>;
    claimedBoxes: Record<string, string>;
    currentPlayerId: string;
    scores: Record<string, number>;
    moveHistory: string[];
    isOver: boolean;
    winnerId: string | null;
    playerIds: string[];
  }) {
    this.rows = opts.rows;
    this.cols = opts.cols;
    this.disabledCells = opts.disabledCells ?? new Set();
    this.drawnEdges = opts.drawnEdges;
    this.edgeOwners = opts.edgeOwners;
    this.claimedBoxes = opts.claimedBoxes;
    this.currentPlayerId = opts.currentPlayerId;
    this.scores = opts.scores;
    this.moveHistory = opts.moveHistory;
    this.isOver = opts.isOver;
    this.winnerId = opts.winnerId;
    this.playerIds = opts.playerIds;
  }

  get totalBoxes(): number {
    return (this.rows - 1) * (this.cols - 1) - this.disabledCells.size;
  }

  get opponentOf(): string {
    return this.currentPlayerId === this.playerIds[0]
      ? this.playerIds[1]
      : this.playerIds[0];
  }

  static initial(opts?: {
    rows?: number;
    cols?: number;
    playerIds?: string[];
    disabledCells?: Set<string>;
  }): GameState {
    const rows = opts?.rows ?? 5;
    const cols = opts?.cols ?? 5;
    const playerIds = opts?.playerIds ?? ['A', 'B'];
    const disabledCells = opts?.disabledCells ?? new Set<string>();
    const scores: Record<string, number> = {};
    for (const id of playerIds) {
      scores[id] = 0;
    }
    return new GameState({
      rows,
      cols,
      disabledCells,
      drawnEdges: new Set(),
      edgeOwners: {},
      claimedBoxes: {},
      currentPlayerId: playerIds[0],
      scores,
      moveHistory: [],
      isOver: false,
      winnerId: null,
      playerIds,
    });
  }

  copyWith(opts: Partial<{
    rows: number;
    cols: number;
    disabledCells: Set<string>;
    drawnEdges: Set<string>;
    edgeOwners: Record<string, string>;
    claimedBoxes: Record<string, string>;
    currentPlayerId: string;
    scores: Record<string, number>;
    moveHistory: string[];
    isOver: boolean;
    winnerId: string | null;
    clearWinner: boolean;
    playerIds: string[];
  }>): GameState {
    return new GameState({
      rows: opts.rows ?? this.rows,
      cols: opts.cols ?? this.cols,
      disabledCells: opts.disabledCells ?? this.disabledCells,
      drawnEdges: opts.drawnEdges ?? this.drawnEdges,
      edgeOwners: opts.edgeOwners ?? this.edgeOwners,
      claimedBoxes: opts.claimedBoxes ?? this.claimedBoxes,
      currentPlayerId: opts.currentPlayerId ?? this.currentPlayerId,
      scores: opts.scores ?? this.scores,
      moveHistory: opts.moveHistory ?? this.moveHistory,
      isOver: opts.isOver ?? this.isOver,
      winnerId: opts.clearWinner ? null : (opts.winnerId ?? this.winnerId),
      playerIds: opts.playerIds ?? this.playerIds,
    });
  }

  toJson(): GameStateJson {
    return {
      rows: this.rows,
      cols: this.cols,
      disabledCells: [...this.disabledCells],
      drawnEdges: [...this.drawnEdges],
      edgeOwners: { ...this.edgeOwners },
      claimedBoxes: { ...this.claimedBoxes },
      currentPlayerId: this.currentPlayerId,
      scores: { ...this.scores },
      moveHistory: [...this.moveHistory],
      isOver: this.isOver,
      winnerId: this.winnerId,
      playerIds: [...this.playerIds],
    };
  }

  static fromJson(json: GameStateJson): GameState {
    const rawOwners = json.edgeOwners ?? {};
    const edgeOwners: Record<string, string> = {};
    for (const [k, v] of Object.entries(rawOwners)) {
      edgeOwners[k] = String(v);
    }
    const scores: Record<string, number> = {};
    for (const [k, v] of Object.entries(json.scores ?? {})) {
      scores[k] = Number(v);
    }
    const claimedBoxes: Record<string, string> = {};
    for (const [k, v] of Object.entries(json.claimedBoxes ?? {})) {
      claimedBoxes[k] = String(v);
    }
    return new GameState({
      rows: Number(json.rows),
      cols: Number(json.cols),
      disabledCells: new Set(json.disabledCells ?? []),
      drawnEdges: new Set(json.drawnEdges ?? []),
      edgeOwners,
      claimedBoxes,
      currentPlayerId: json.currentPlayerId,
      scores,
      moveHistory: [...(json.moveHistory ?? [])],
      isOver: Boolean(json.isOver),
      winnerId: json.winnerId ?? null,
      playerIds: [...(json.playerIds ?? ['A', 'B'])],
    });
  }
}

type ParsedEdge = { isH: boolean; row: number; col: number };
type BoxCoord = [number, number];

export class GameRules {
  static hEdge(row: number, col: number): string {
    return `H_${row}_${col}`;
  }

  static vEdge(row: number, col: number): string {
    return `V_${row}_${col}`;
  }

  static boxKey(row: number, col: number): string {
    return `${row}_${col}`;
  }

  static parseEdge(key: string): ParsedEdge {
    const parts = key.split('_');
    return {
      isH: parts[0] === 'H',
      row: Number(parts[1]),
      col: Number(parts[2]),
    };
  }

  static boxEdges(row: number, col: number): string[] {
    return [
      GameRules.hEdge(row, col),
      GameRules.hEdge(row + 1, col),
      GameRules.vEdge(row, col),
      GameRules.vEdge(row, col + 1),
    ];
  }

  static adjacentBoxes(rows: number, cols: number, edgeKey: string): BoxCoord[] {
    const { isH, row, col } = GameRules.parseEdge(edgeKey);
    const result: BoxCoord[] = [];

    if (isH) {
      if (row > 0 && col < cols - 1) result.push([row - 1, col]);
      if (row < rows - 1 && col < cols - 1) result.push([row, col]);
    } else {
      if (col > 0 && row < rows - 1) result.push([row, col - 1]);
      if (col < cols - 1 && row < rows - 1) result.push([row, col]);
    }
    return result;
  }

  private static isEdgeInDisabledRegion(state: GameState, edgeKey: string): boolean {
    if (state.disabledCells.size === 0) return false;
    const adjacent = GameRules.adjacentBoxes(state.rows, state.cols, edgeKey);
    if (adjacent.length === 0) return false;
    return adjacent.every(([r, c]) =>
      state.disabledCells.has(GameRules.boxKey(r, c)),
    );
  }

  static isLegalMove(state: GameState, edgeKey: string): boolean {
    if (state.isOver) return false;
    if (state.drawnEdges.has(edgeKey)) return false;

    const { isH, row, col } = GameRules.parseEdge(edgeKey);
    let inBounds: boolean;
    if (isH) {
      inBounds = row >= 0 && row < state.rows && col >= 0 && col < state.cols - 1;
    } else {
      inBounds = row >= 0 && row < state.rows - 1 && col >= 0 && col < state.cols;
    }
    if (!inBounds) return false;
    if (GameRules.isEdgeInDisabledRegion(state, edgeKey)) return false;
    return true;
  }

  static applyMove(state: GameState, edgeKey: string): GameState {
    if (!GameRules.isLegalMove(state, edgeKey)) {
      throw new Error(`Illegal move: ${edgeKey}`);
    }

    const newEdges = new Set(state.drawnEdges);
    newEdges.add(edgeKey);

    const newEdgeOwners = { ...state.edgeOwners };
    newEdgeOwners[edgeKey] = state.currentPlayerId;

    const newlyClaimed: string[] = [];
    for (const [r, c] of GameRules.adjacentBoxes(state.rows, state.cols, edgeKey)) {
      const bKey = GameRules.boxKey(r, c);
      if (state.disabledCells.has(bKey)) continue;
      if (bKey in state.claimedBoxes) continue;

      const edges = GameRules.boxEdges(r, c);
      if (edges.every((e) => newEdges.has(e))) {
        newlyClaimed.push(bKey);
      }
    }

    const newClaimed = { ...state.claimedBoxes };
    const newScores = { ...state.scores };

    for (const bKey of newlyClaimed) {
      newClaimed[bKey] = state.currentPlayerId;
      newScores[state.currentPlayerId] = (newScores[state.currentPlayerId] ?? 0) + 1;
    }

    const nextPlayer =
      newlyClaimed.length > 0 ? state.currentPlayerId : state.opponentOf;

    const isOver = Object.keys(newClaimed).length === state.totalBoxes;

    let winner: string | null = null;
    if (isOver) {
      const ids = state.playerIds;
      const aScore = newScores[ids[0]] ?? 0;
      const bScore = newScores[ids[1]] ?? 0;
      if (aScore > bScore) {
        winner = ids[0];
      } else if (bScore > aScore) {
        winner = ids[1];
      }
    }

    return state.copyWith({
      drawnEdges: newEdges,
      edgeOwners: newEdgeOwners,
      claimedBoxes: newClaimed,
      scores: newScores,
      currentPlayerId: nextPlayer,
      moveHistory: [...state.moveHistory, edgeKey],
      isOver,
      winnerId: winner,
      clearWinner: isOver && winner === null,
    });
  }

  static legalMoves(state: GameState): string[] {
    const moves: string[] = [];
    for (let r = 0; r < state.rows; r++) {
      for (let c = 0; c < state.cols - 1; c++) {
        const k = GameRules.hEdge(r, c);
        if (GameRules.isLegalMove(state, k)) moves.push(k);
      }
    }
    for (let r = 0; r < state.rows - 1; r++) {
      for (let c = 0; c < state.cols; c++) {
        const k = GameRules.vEdge(r, c);
        if (GameRules.isLegalMove(state, k)) moves.push(k);
      }
    }
    return moves;
  }
}
