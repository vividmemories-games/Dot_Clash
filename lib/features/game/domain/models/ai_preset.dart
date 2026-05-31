import 'dart:math';

/// Named board layout for VS AI challenge mode (always hard AI).
class AiPreset {
  const AiPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.rows,
    required this.cols,
    this.disabledCells = const [],
  });

  final String id;
  final String name;
  final String description;
  final int rows;
  final int cols;
  final List<String> disabledCells;

  static final _rng = Random();

  static final List<AiPreset> all = [
    const AiPreset(
      id: 'standard',
      name: 'Standard',
      description: 'Classic square grid — pure dots and boxes.',
      rows: 5,
      cols: 5,
    ),
    AiPreset(
      id: 'fortress',
      name: 'Fortress',
      description: 'A void blocks the center — fight around the fortress.',
      rows: 5,
      cols: 5,
      disabledCells: _boxBlock(4, 4, 1, 1, 3, 3),
    ),
    const AiPreset(
      id: 'blitz',
      name: 'Blitz',
      description: 'Tiny board — every line counts, games end fast.',
      rows: 4,
      cols: 4,
    ),
    AiPreset(
      id: 'maze',
      name: 'Maze',
      description: 'Corners carved away — irregular edges everywhere.',
      rows: 6,
      cols: 6,
      disabledCells: const [
        '0_0',
        '0_5',
        '1_0',
        '1_5',
        '4_0',
        '4_5',
        '5_0',
        '5_5',
        '0_1',
        '1_4',
        '4_1',
        '5_4',
      ],
    ),
    const AiPreset(
      id: 'gauntlet',
      name: 'Gauntlet',
      description: 'Narrow corridor — long flanks, tight middle.',
      rows: 7,
      cols: 4,
    ),
    const AiPreset(
      id: 'arena',
      name: 'Arena',
      description: 'Wide open field — room for long chains.',
      rows: 7,
      cols: 7,
    ),
    AiPreset(
      id: 'donut',
      name: 'Donut',
      description: 'Hollow center — capture the ring around the void.',
      rows: 6,
      cols: 6,
      disabledCells: const ['2_2', '2_3', '3_2', '3_3'],
    ),
    AiPreset(
      id: 'crossroads',
      name: 'Crossroads',
      description: 'A cross-shaped void splits the board into four zones.',
      rows: 7,
      cols: 7,
      disabledCells: _crossroadsDisabled(6, 6),
    ),
    const AiPreset(
      id: 'sniper',
      name: 'Sniper',
      description: 'Long thin strip — sequential pressure, no escape.',
      rows: 9,
      cols: 3,
    ),
    AiPreset(
      id: 'shattered',
      name: 'Shattered',
      description: 'Scattered voids — territory shifts every match.',
      rows: 6,
      cols: 6,
      disabledCells: const [
        '0_0',
        '0_4',
        '2_2',
        '4_0',
        '4_4',
        '1_2',
        '3_1',
        '3_3',
      ],
    ),
  ];

  static AiPreset random() => all[_rng.nextInt(all.length)];

  static AiPreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Inclusive box indices on a grid with [maxRow]×[maxCol] boxes (0-based).
  static List<String> _boxBlock(
    int maxRow,
    int maxCol,
    int r0,
    int c0,
    int r1,
    int c1,
  ) {
    final keys = <String>[];
    for (var r = r0; r <= r1 && r < maxRow; r++) {
      for (var c = c0; c <= c1 && c < maxCol; c++) {
        keys.add('${r}_$c');
      }
    }
    return keys;
  }

  /// Plus-shaped void on a [boxRows]×[boxCols] box grid (~17 cells on 6×6).
  static List<String> _crossroadsDisabled(int boxRows, int boxCols) {
    final disabled = <String>{};
    final midR = boxRows ~/ 2;
    final midC = boxCols ~/ 2;
    for (var c = 0; c < boxCols; c++) {
      disabled.add('${midR - 1}_$c');
      disabled.add('${midR}_$c');
    }
    for (var r = 0; r < boxRows; r++) {
      if (r == midR - 1 || r == midR) continue;
      disabled.add('${r}_${midC - 1}');
      disabled.add('${r}_$midC');
    }
    return disabled.toList();
  }
}
