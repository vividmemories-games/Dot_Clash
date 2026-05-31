import '../../profile/domain/progression.dart';
import 'campaign_world.dart';

/// Campaign progress derived from the profile document.
class CampaignProgress {
  const CampaignProgress({
    required this.starsByLevelId,
    this.lastLevelId,
  });

  /// Best stars per level id, e.g. {"w1_l01": 3, "w1_l02": 1}.
  final Map<String, int> starsByLevelId;
  final String? lastLevelId;

  int get totalStars => Progression.totalStarsFromMap(starsByLevelId);
  int get playerLevel => Progression.levelForStars(totalStars);

  int starsFor(String levelId) => starsByLevelId[levelId] ?? 0;

  bool hasCleared(String levelId) => starsFor(levelId) >= 1;

  int starsForWorld(int worldId) {
    final world = CampaignCatalog.worldById(worldId);
    var total = 0;
    for (var i = 1; i <= world.levelCount; i++) {
      total += starsFor(CampaignCatalog.levelId(worldId, i));
    }
    return total;
  }

  bool isLevelUnlocked(String levelId) {
    final first = CampaignCatalog.levelId(1, 1);
    if (levelId == first) return true;
    final prev = _previousLevelId(levelId);
    return prev != null && hasCleared(prev);
  }

  bool isWorldUnlocked(int worldId) {
    if (worldId <= 1) return true;
    final prevWorld = CampaignCatalog.worldById(worldId - 1);
    if (prevWorld.worldGateRequiresFinale) {
      final finaleId =
          CampaignCatalog.levelId(prevWorld.id, prevWorld.levelCount);
      return hasCleared(finaleId);
    }
    final earned = starsForWorld(prevWorld.id);
    return earned >= (prevWorld.worldGateMinStars ?? 1);
  }

  /// The next level to play: first unlocked level not yet cleared (≥1★).
  /// Replay for 2★/3★ is via the campaign map, not Continue.
  String? get continueLevelId {
    for (final world in CampaignCatalog.worlds) {
      if (!isWorldUnlocked(world.id)) break;
      for (var i = 1; i <= world.levelCount; i++) {
        final id = CampaignCatalog.levelId(world.id, i);
        if (!isLevelUnlocked(id)) return null;
        if (!hasCleared(id)) return id;
      }
    }
    return null;
  }

  static String? _previousLevelId(String levelId) {
    final parts = CampaignCatalog.parseLevelId(levelId);
    if (parts == null) return null;
    final (worldId, index) = parts;
    if (index > 1) return CampaignCatalog.levelId(worldId, index - 1);
    if (worldId <= 1) return null;
    final prevWorld = CampaignCatalog.worldById(worldId - 1);
    return CampaignCatalog.levelId(prevWorld.id, prevWorld.levelCount);
  }

  CampaignProgress withResult(String levelId, int newStars) {
    final current = starsFor(levelId);
    if (newStars <= current) return this;
    return CampaignProgress(
      starsByLevelId: {...starsByLevelId, levelId: newStars},
      lastLevelId: levelId,
    );
  }
}
