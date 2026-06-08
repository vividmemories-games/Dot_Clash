import 'progression.dart';
import 'rank.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.coins,
    required this.xp,
    required this.level,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.gamesPlayed,
    required this.winStreak,
    required this.bestWinStreak,
    required this.seasonId,
    required this.rating,
    required this.seasonBestRating,
    required this.seasonWins,
    required this.seasonLosses,
    required this.seasonTies,
    required this.themeId,
    required this.avatarId,
    required this.initialSkinId,
    required this.removeAds,
    required this.ownedThemeIds,
    required this.ownedAvatarIds,
    required this.ownedInitialSkinIds,
    required this.lives,
    this.nextLifeAt,
    this.lastDailyClaimAt,
    this.lastRewardedAdAt,
    this.campaignStars = const {},
    this.lastCampaignLevelId,
    this.dailyPuzzleDate,
    this.dailyPuzzleLevelId,
    this.dailyPuzzleCompleted = false,
    this.dailyPuzzleStreak = 0,
    this.dailyMissions = const DailyMissionProgress.empty(),
    this.powerUpInventory = const {},
  });

  final String uid;

  final String displayName;

  // Economy
  final int coins;
  final bool removeAds;

  // Progression
  final int xp;
  final int level;

  // Lifetime stats
  final int wins;
  final int losses;
  final int ties;
  final int gamesPlayed;
  final int winStreak;
  final int bestWinStreak;

  // Monthly season
  final String seasonId;
  final int rating;
  final int seasonBestRating;
  final int seasonWins;
  final int seasonLosses;
  final int seasonTies;

  RankTier get rankTier => RankSystem.tierForRating(rating);

  // Cosmetics
  final String themeId;
  final String avatarId;
  final String initialSkinId;

  final List<String> ownedThemeIds;
  final List<String> ownedAvatarIds;
  final List<String> ownedInitialSkinIds;

  // Lives
  final int lives;
  final DateTime? nextLifeAt;

  // Cooldowns
  final DateTime? lastDailyClaimAt;
  final DateTime? lastRewardedAdAt;

  // Campaign progress stored on the profile document
  /// Best stars per campaign level ID, e.g. {"w1_l01": 3, "w1_l02": 2}.
  final Map<String, int> campaignStars;
  final String? lastCampaignLevelId;

  /// UTC date key (yyyy-MM-dd) for today's daily puzzle.
  final String? dailyPuzzleDate;
  final String? dailyPuzzleLevelId;
  final bool dailyPuzzleCompleted;
  final int dailyPuzzleStreak;

  final DailyMissionProgress dailyMissions;

  /// Consumable boost counts keyed by [PowerUpType.id].
  final Map<String, int> powerUpInventory;

  int powerUpCount(String id) => powerUpInventory[id] ?? 0;

  int get totalCampaignStars => Progression.totalStarsFromMap(campaignStars);

  bool get isDailyPuzzleCompletedToday {
    final today = DailyMissionProgress.todayUtc();
    return dailyPuzzleDate == today && dailyPuzzleCompleted;
  }

  /// Player level derived from total campaign stars (replaces XP-based level).
  int get campaignPlayerLevel => Progression.levelForStars(totalCampaignStars);

  UserProfile copyWith({
    String? displayName,
    int? coins,
    bool? removeAds,
    int? xp,
    int? level,
    int? wins,
    int? losses,
    int? ties,
    int? gamesPlayed,
    int? winStreak,
    int? bestWinStreak,
    String? seasonId,
    int? rating,
    int? seasonBestRating,
    int? seasonWins,
    int? seasonLosses,
    int? seasonTies,
    String? themeId,
    String? avatarId,
    String? initialSkinId,
    List<String>? ownedThemeIds,
    List<String>? ownedAvatarIds,
    List<String>? ownedInitialSkinIds,
    int? lives,
    DateTime? nextLifeAt,
    DateTime? lastDailyClaimAt,
    DateTime? lastRewardedAdAt,
    bool clearLastDailyClaimAt = false,
    Map<String, int>? campaignStars,
    String? lastCampaignLevelId,
    bool clearLastCampaignLevelId = false,
    String? dailyPuzzleDate,
    String? dailyPuzzleLevelId,
    bool? dailyPuzzleCompleted,
    int? dailyPuzzleStreak,
    DailyMissionProgress? dailyMissions,
    Map<String, int>? powerUpInventory,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      coins: coins ?? this.coins,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      ties: ties ?? this.ties,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      winStreak: winStreak ?? this.winStreak,
      bestWinStreak: bestWinStreak ?? this.bestWinStreak,
      seasonId: seasonId ?? this.seasonId,
      rating: rating ?? this.rating,
      seasonBestRating: seasonBestRating ?? this.seasonBestRating,
      seasonWins: seasonWins ?? this.seasonWins,
      seasonLosses: seasonLosses ?? this.seasonLosses,
      seasonTies: seasonTies ?? this.seasonTies,
      themeId: themeId ?? this.themeId,
      avatarId: avatarId ?? this.avatarId,
      initialSkinId: initialSkinId ?? this.initialSkinId,
      removeAds: removeAds ?? this.removeAds,
      ownedThemeIds: ownedThemeIds ?? this.ownedThemeIds,
      ownedAvatarIds: ownedAvatarIds ?? this.ownedAvatarIds,
      ownedInitialSkinIds: ownedInitialSkinIds ?? this.ownedInitialSkinIds,
      lives: lives ?? this.lives,
      nextLifeAt: nextLifeAt ?? this.nextLifeAt,
      lastDailyClaimAt: clearLastDailyClaimAt
          ? null
          : (lastDailyClaimAt ?? this.lastDailyClaimAt),
      lastRewardedAdAt: lastRewardedAdAt ?? this.lastRewardedAdAt,
      campaignStars: campaignStars ?? this.campaignStars,
      lastCampaignLevelId: clearLastCampaignLevelId
          ? null
          : (lastCampaignLevelId ?? this.lastCampaignLevelId),
      dailyPuzzleDate: dailyPuzzleDate ?? this.dailyPuzzleDate,
      dailyPuzzleLevelId: dailyPuzzleLevelId ?? this.dailyPuzzleLevelId,
      dailyPuzzleCompleted: dailyPuzzleCompleted ?? this.dailyPuzzleCompleted,
      dailyPuzzleStreak: dailyPuzzleStreak ?? this.dailyPuzzleStreak,
      dailyMissions: dailyMissions ?? this.dailyMissions,
      powerUpInventory: powerUpInventory ?? this.powerUpInventory,
    );
  }
}

/// Per-day mission counters reset at UTC midnight.
class DailyMissionProgress {
  const DailyMissionProgress({
    required this.date,
    required this.wins,
    required this.games,
    required this.boxes,
    required this.claimedIds,
  });

  const DailyMissionProgress.empty()
      : date = '',
        wins = 0,
        games = 0,
        boxes = 0,
        claimedIds = const {};

  final String date;
  final int wins;
  final int games;
  final int boxes;
  final Set<String> claimedIds;

  static String todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  DailyMissionProgress forToday() {
    final today = todayUtc();
    if (date == today) return this;
    return DailyMissionProgress(
      date: today,
      wins: 0,
      games: 0,
      boxes: 0,
      claimedIds: const {},
    );
  }

  int progressFor(String missionId) => switch (missionId) {
        'win_matches' => wins,
        'play_games' => games,
        'capture_boxes' => boxes,
        _ => 0,
      };

  bool isClaimed(String missionId) => claimedIds.contains(missionId);

  DailyMissionProgress copyWithBump({
    bool win = false,
    bool gamePlayed = false,
    int boxesCaptured = 0,
  }) {
    final today = forToday();
    return DailyMissionProgress(
      date: today.date,
      wins: today.wins + (win ? 1 : 0),
      games: today.games + (gamePlayed ? 1 : 0),
      boxes: today.boxes + boxesCaptured,
      claimedIds: today.claimedIds,
    );
  }

  DailyMissionProgress withClaimed(String missionId) {
    final today = forToday();
    return DailyMissionProgress(
      date: today.date,
      wins: today.wins,
      games: today.games,
      boxes: today.boxes,
      claimedIds: {...today.claimedIds, missionId},
    );
  }
}
