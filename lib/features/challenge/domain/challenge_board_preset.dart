import '../../game/domain/models/ai_preset.dart';

/// Host-selectable Challenge board layout — mirrors `functions/src/challenge_board_presets.ts`.
class ChallengeBoardPreset {
  const ChallengeBoardPreset({
    required this.id,
    required this.name,
    required this.tagline,
    required this.rows,
    required this.cols,
    this.disabledCells = const [],
    required this.sortOrder,
    required this.estimatedMinutes,
  });

  final String id;
  final String name;
  final String tagline;
  final int rows;
  final int cols;
  final List<String> disabledCells;
  final int sortOrder;
  final String estimatedMinutes;

  static const defaultPresetId = 'challenge_classic';

  static final List<ChallengeBoardPreset> all = [
    const ChallengeBoardPreset(
      id: 'challenge_classic',
      name: 'Classic',
      tagline: '6×6 · standard grid',
      rows: 6,
      cols: 6,
      sortOrder: 0,
      estimatedMinutes: '~8–12 min',
    ),
    const ChallengeBoardPreset(
      id: 'challenge_blitz',
      name: 'Blitz',
      tagline: '4×4 · fast finish',
      rows: 4,
      cols: 4,
      sortOrder: 1,
      estimatedMinutes: '~2–4 min',
    ),
    ChallengeBoardPreset(
      id: 'challenge_fortress',
      name: 'Fortress',
      tagline: '5×5 · center blocked',
      rows: 5,
      cols: 5,
      disabledCells: AiPreset.byId('fortress')!.disabledCells,
      sortOrder: 2,
      estimatedMinutes: '~3–5 min',
    ),
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  static ChallengeBoardPreset get defaultPreset =>
      byId(defaultPresetId) ?? all.first;

  static ChallengeBoardPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
