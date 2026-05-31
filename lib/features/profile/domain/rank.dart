enum RankTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  master,
}

abstract final class RankSystem {
  static String currentSeasonId(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

  static RankTier tierForRating(int rating) {
    if (rating >= 1600) return RankTier.master;
    if (rating >= 1450) return RankTier.diamond;
    if (rating >= 1300) return RankTier.platinum;
    if (rating >= 1150) return RankTier.gold;
    if (rating >= 1050) return RankTier.silver;
    return RankTier.bronze;
  }

  static String label(RankTier tier) => switch (tier) {
        RankTier.bronze => 'Bronze',
        RankTier.silver => 'Silver',
        RankTier.gold => 'Gold',
        RankTier.platinum => 'Platinum',
        RankTier.diamond => 'Diamond',
        RankTier.master => 'Master',
      };
}

