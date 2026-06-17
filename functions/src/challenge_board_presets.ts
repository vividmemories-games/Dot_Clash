import { GameState } from './game_rules';

/** Minimum playable boxes for a Challenge preset (server guard). */
export const MIN_PLAYABLE_BOXES = 6;

export interface ChallengeBoardPreset {
  id: string;
  name: string;
  tagline: string;
  rows: number;
  cols: number;
  disabledCells: readonly string[];
  sortOrder: number;
  estimatedMinutes: string;
}

export const DEFAULT_CHALLENGE_PRESET_ID = 'challenge_classic';

/** Center 3×3 void on a 4×4 box grid (5×5 dots) — matches Dart AiPreset fortress. */
const FORTRESS_DISABLED_CELLS = boxBlock(4, 4, 1, 1, 3, 3);

export const CHALLENGE_BOARD_PRESETS: readonly ChallengeBoardPreset[] = [
  {
    id: 'challenge_classic',
    name: 'Classic',
    tagline: '6×6 · standard grid',
    rows: 6,
    cols: 6,
    disabledCells: [],
    sortOrder: 0,
    estimatedMinutes: '~8–12 min',
  },
  {
    id: 'challenge_blitz',
    name: 'Blitz',
    tagline: '4×4 · fast finish',
    rows: 4,
    cols: 4,
    disabledCells: [],
    sortOrder: 1,
    estimatedMinutes: '~2–4 min',
  },
  {
    id: 'challenge_fortress',
    name: 'Fortress',
    tagline: '5×5 · center blocked',
    rows: 5,
    cols: 5,
    disabledCells: FORTRESS_DISABLED_CELLS,
    sortOrder: 2,
    estimatedMinutes: '~3–5 min',
  },
] as const;

const PRESET_BY_ID = new Map(
  CHALLENGE_BOARD_PRESETS.map((preset) => [preset.id, preset]),
);

export class InvalidChallengePresetError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidChallengePresetError';
  }
}

/** Inclusive box indices on a grid with [maxRow]×[maxCol] boxes (0-based). */
function boxBlock(
  maxRow: number,
  maxCol: number,
  r0: number,
  c0: number,
  r1: number,
  c1: number,
): string[] {
  const keys: string[] = [];
  for (let r = r0; r <= r1 && r < maxRow; r++) {
    for (let c = c0; c <= c1 && c < maxCol; c++) {
      keys.push(`${r}_${c}`);
    }
  }
  return keys;
}

function playableBoxCount(preset: ChallengeBoardPreset): number {
  const boxRows = preset.rows - 1;
  const boxCols = preset.cols - 1;
  return boxRows * boxCols - preset.disabledCells.length;
}

function isValidBoxKey(rows: number, cols: number, key: string): boolean {
  const parts = key.split('_');
  if (parts.length !== 2) return false;
  const r = Number(parts[0]);
  const c = Number(parts[1]);
  if (!Number.isInteger(r) || !Number.isInteger(c)) return false;
  return r >= 0 && r < rows - 1 && c >= 0 && c < cols - 1;
}

function validatePresetGeometry(preset: ChallengeBoardPreset): void {
  if (preset.rows !== preset.cols) {
    throw new InvalidChallengePresetError(
      `Preset ${preset.id} must use a square grid.`,
    );
  }
  if (preset.rows < 4 || preset.rows > 7) {
    throw new InvalidChallengePresetError(
      `Preset ${preset.id} rows/cols must be in [4, 7].`,
    );
  }
  for (const key of preset.disabledCells) {
    if (!isValidBoxKey(preset.rows, preset.cols, key)) {
      throw new InvalidChallengePresetError(
        `Preset ${preset.id} has invalid disabled cell ${key}.`,
      );
    }
  }
  const playable = playableBoxCount(preset);
  if (playable < MIN_PLAYABLE_BOXES) {
    throw new InvalidChallengePresetError(
      `Preset ${preset.id} has only ${playable} playable boxes (min ${MIN_PLAYABLE_BOXES}).`,
    );
  }
}

for (const preset of CHALLENGE_BOARD_PRESETS) {
  validatePresetGeometry(preset);
}

/**
 * Resolve a client-supplied preset id against the server allowlist.
 * Missing/empty id defaults to Classic (backward compatible with build 19).
 */
export function resolveChallengePreset(boardPresetId: unknown): ChallengeBoardPreset {
  const id =
    typeof boardPresetId === 'string' && boardPresetId.trim().length > 0
      ? boardPresetId.trim()
      : DEFAULT_CHALLENGE_PRESET_ID;

  const preset = PRESET_BY_ID.get(id);
  if (!preset) {
    throw new InvalidChallengePresetError(`Unknown board preset: ${id}`);
  }
  return preset;
}

export function initialGameStateForPreset(preset: ChallengeBoardPreset): GameState {
  return GameState.initial({
    rows: preset.rows,
    cols: preset.cols,
    playerIds: ['A', 'B'],
    disabledCells: new Set(preset.disabledCells),
  });
}
