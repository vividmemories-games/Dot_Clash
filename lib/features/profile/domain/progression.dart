abstract final class Progression {
  /// Simple XP curve: each level requires `base + level*step` XP.
  static const int baseXp = 100;
  static const int stepXp = 25;
  static const int maxLives = 5;
  static const Duration lifeRegenDuration = Duration(minutes: 20);
  static const int lifeRefillPriceCoins = 100;

  // ── Campaign star-based player level ──────────────────────────────────────
  // Player level = f(total campaign stars). Max 300 stars (100 levels × 3★).
  // Level curve: each level from 1 requires ~12+2*(level-1) stars, giving
  // ~20 player levels over the full campaign.

  static const int maxCampaignStars = 300;

  /// Stars required to advance from [level] to [level + 1].
  static int starsToAdvanceFromPlayerLevel(int level) => 12 + (level - 1) * 3;

  /// Cumulative stars needed to have reached player [level] (Lv 1 = 0 stars).
  static int starsForPlayerLevel(int level) {
    if (level <= 1) return 0;
    var total = 0;
    for (var l = 1; l < level; l++) {
      total += starsToAdvanceFromPlayerLevel(l);
    }
    return total;
  }

  /// Derives player level from total campaign stars collected.
  static int levelForStars(int totalStars) {
    if (totalStars <= 0) return 1;
    var level = 1;
    while (level < 50 && totalStars >= starsForPlayerLevel(level + 1)) {
      level++;
    }
    return level;
  }

  /// Progress of [totalStars] within the current player level.
  static ({int intoLevel, int forLevel, double fraction}) starsInCurrentPlayerLevel(
    int totalStars,
  ) {
    final level = levelForStars(totalStars);
    final floor = starsForPlayerLevel(level);
    final ceiling = starsForPlayerLevel(level + 1);
    final span = ceiling - floor;
    final into = (totalStars - floor).clamp(0, span);
    return (
      intoLevel: into,
      forLevel: span,
      fraction: span <= 0 ? 0.0 : (into / span).clamp(0.0, 1.0),
    );
  }

  /// Sum of best-stars across all campaign levels.
  static int totalStarsFromMap(Map<String, int> starsByLevelId) =>
      starsByLevelId.values.fold<int>(0, (sum, s) => sum + s.clamp(0, 3));

  static int levelForXp(int xp) {
    var level = 1;
    var remaining = xp;
    while (remaining >= xpForLevel(level)) {
      remaining -= xpForLevel(level);
      level++;
      if (level > 200) break;
    }
    return level;
  }

  static int xpForLevel(int level) => baseXp + (level - 1) * stepXp;

  static ({int intoLevel, int forLevel, double fraction}) xpInCurrentLevel(
    int totalXp,
  ) {
    if (totalXp <= 0) {
      final firstLevelXp = xpForLevel(1);
      return (intoLevel: 0, forLevel: firstLevelXp, fraction: 0);
    }

    var level = 1;
    var remaining = totalXp;
    while (remaining >= xpForLevel(level)) {
      remaining -= xpForLevel(level);
      level++;
      if (level > 200) break;
    }

    final xpForCurrentLevel = xpForLevel(level);
    final rawFraction = remaining / xpForCurrentLevel;
    return (
      intoLevel: remaining,
      forLevel: xpForCurrentLevel,
      fraction: rawFraction.clamp(0.0, 1.0),
    );
  }

  static int coinsForMatch({required bool win, required bool tie}) {
    if (tie) return 8;
    return win ? 15 : 6;
  }

  static int xpForMatch({required bool win, required bool tie}) {
    if (tie) return 14;
    return win ? 22 : 10;
  }
}
