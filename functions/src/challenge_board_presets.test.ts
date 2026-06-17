/**
 * Parity vectors for Challenge board presets — keep in sync with
 * test/challenge/challenge_board_presets_test.dart
 */
import {
  CHALLENGE_BOARD_PRESETS,
  DEFAULT_CHALLENGE_PRESET_ID,
  initialGameStateForPreset,
  InvalidChallengePresetError,
  resolveChallengePreset,
} from './challenge_board_presets';
import { GameRules } from './game_rules';

interface PresetVector {
  id: string;
  rows: number;
  cols: number;
  totalBoxes: number;
  initialLegalMoves: number;
  disabledCells: string[];
}

const PRESET_VECTORS: PresetVector[] = [
  {
    id: 'challenge_classic',
    rows: 6,
    cols: 6,
    totalBoxes: 25,
    initialLegalMoves: 60,
    disabledCells: [],
  },
  {
    id: 'challenge_blitz',
    rows: 4,
    cols: 4,
    totalBoxes: 9,
    initialLegalMoves: 24,
    disabledCells: [],
  },
  {
    id: 'challenge_fortress',
    rows: 5,
    cols: 5,
    totalBoxes: 7,
    initialLegalMoves: 22,
    disabledCells: [
      '1_1', '1_2', '1_3',
      '2_1', '2_2', '2_3',
      '3_1', '3_2', '3_3',
    ],
  },
];

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function runTests(): void {
  assert(
    CHALLENGE_BOARD_PRESETS.length === 3,
    'Expected exactly 3 challenge presets',
  );

  for (const vector of PRESET_VECTORS) {
    const preset = resolveChallengePreset(vector.id);
    assert(preset.rows === vector.rows, `${vector.id} rows mismatch`);
    assert(preset.cols === vector.cols, `${vector.id} cols mismatch`);
    assert(
      [...preset.disabledCells].sort().join(',') === vector.disabledCells.sort().join(','),
      `${vector.id} disabledCells mismatch`,
    );

    const state = initialGameStateForPreset(preset);
    assert(state.totalBoxes === vector.totalBoxes, `${vector.id} totalBoxes mismatch`);
    assert(
      GameRules.legalMoves(state).length === vector.initialLegalMoves,
      `${vector.id} initialLegalMoves mismatch`,
    );
    assert(state.currentPlayerId === 'A', `${vector.id} should start on player A`);
    assert(!state.isOver, `${vector.id} should not start over`);
  }

  assert(
    resolveChallengePreset(undefined).id === DEFAULT_CHALLENGE_PRESET_ID,
    'Missing preset id should default to classic',
  );
  assert(
    resolveChallengePreset('').id === DEFAULT_CHALLENGE_PRESET_ID,
    'Empty preset id should default to classic',
  );

  let rejected = false;
  try {
    resolveChallengePreset('invalid');
  } catch (err) {
    rejected = err instanceof InvalidChallengePresetError;
  }
  assert(rejected, 'Invalid preset id should throw InvalidChallengePresetError');

  console.log('challenge_board_presets.test: all assertions passed');
}

runTests();
