/// Static metadata for each campaign world.
class CampaignWorld {
  const CampaignWorld({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.levelCount,
    required this.bossLevelIndexes,
    required this.worldGateRequiresFinale,
    this.worldGateMinStars,
  });

  final int id;
  final String title;
  final String subtitle;

  /// Total playable levels in this world (not counting repeat plays).
  final int levelCount;

  /// 1-based level indexes that are boss nodes.
  final List<int> bossLevelIndexes;

  /// If true, player must beat the world finale (last boss) to unlock next world.
  final bool worldGateRequiresFinale;

  /// Minimum total stars within this world needed to unlock the next world
  /// (only enforced when [worldGateRequiresFinale] is false).
  final int? worldGateMinStars;

  int get maxStars => levelCount * 3;
}

/// Static catalog of all 5 campaign worlds.
abstract final class CampaignCatalog {
  static const worlds = <CampaignWorld>[
    CampaignWorld(
      id: 1,
      title: 'Basics',
      subtitle: 'Back of the notebook',
      levelCount: 10,
      bossLevelIndexes: [5, 10],
      worldGateRequiresFinale: true,
    ),
    CampaignWorld(
      id: 2,
      title: 'Chain Tactics',
      subtitle: 'Study hall chains',
      levelCount: 20,
      bossLevelIndexes: [10, 20],
      worldGateRequiresFinale: false,
      worldGateMinStars: 18,
    ),
    CampaignWorld(
      id: 3,
      title: 'Trap Masters',
      subtitle: 'Lunch table traps',
      levelCount: 25,
      bossLevelIndexes: [10, 20, 25],
      worldGateRequiresFinale: false,
      worldGateMinStars: 22,
    ),
    CampaignWorld(
      id: 4,
      title: 'Speed Arena',
      subtitle: 'Beat the bell',
      levelCount: 25,
      bossLevelIndexes: [10, 20, 25],
      worldGateRequiresFinale: false,
      worldGateMinStars: 22,
    ),
    CampaignWorld(
      id: 5,
      title: 'Chaos Grid',
      subtitle: 'Broken grids',
      levelCount: 20,
      bossLevelIndexes: [10, 20],
      worldGateRequiresFinale: false,
      worldGateMinStars: 15,
    ),
  ];

  static const int totalLevels = 100;
  static const int totalBosses = 12;

  static CampaignWorld worldById(int id) =>
      worlds.firstWhere((w) => w.id == id, orElse: () => worlds.first);

  static String levelId(int worldId, int levelIndex) =>
      'w${worldId}_l${levelIndex.toString().padLeft(2, '0')}';

  static (int worldId, int index)? parseLevelId(String levelId) {
    final match = RegExp(r'^w(\d+)_l(\d+)$').firstMatch(levelId);
    if (match == null) return null;
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }
}
