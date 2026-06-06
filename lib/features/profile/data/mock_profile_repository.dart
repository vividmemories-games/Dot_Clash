import 'dart:async';

import 'profile_repository.dart';
import '../domain/lives_logic.dart';
import '../domain/progression.dart';
import '../domain/rank.dart';
import '../domain/user_profile.dart';
import '../../powerups/domain/power_up.dart';
import '../../powerups/domain/power_up_catalog.dart';

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository();

  final _controller = StreamController<UserProfile>.broadcast();
  final _matchesController = StreamController<List<RecentMatchRecord>>.broadcast();
  final List<RecentMatchRecord> _matches = [];

  late UserProfile _profile = _defaultProfile();

  Stream<UserProfile> watchProfile() async* {
    yield _profile;
    yield* _controller.stream;
  }

  UserProfile get current => _profile;

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    _emit(_profile.copyWith(displayName: trimmed.isEmpty ? 'Player' : trimmed));
  }

  Future<void> equipTheme(String themeId) async {
    _emit(_profile.copyWith(themeId: themeId));
  }

  Future<void> equipAvatar(String avatarId) async {
    _emit(_profile.copyWith(avatarId: avatarId));
  }

  Future<void> equipInitialSkin(String skinId) async {
    _emit(_profile.copyWith(initialSkinId: skinId));
  }

  @override
  Future<bool> verifyRemoveAdsPurchase({
    required String platform,
    required String productId,
    String? packageName,
    String? purchaseToken,
    String? verificationData,
    String? localVerificationData,
  }) async {
    return grantRemoveAds();
  }

  @override
  Future<bool> grantRemoveAds() async {
    if (_profile.removeAds) return true;
    _emit(_profile.copyWith(removeAds: true));
    return true;
  }

  Future<bool> purchaseTheme(String themeId, int priceCoins) async {
    if (_profile.ownedThemeIds.contains(themeId)) return true;
    if (_profile.coins < priceCoins) return false;
    _emit(_profile.copyWith(
      coins: _profile.coins - priceCoins,
      ownedThemeIds: [..._profile.ownedThemeIds, themeId],
      themeId: themeId,
    ));
    return true;
  }

  Future<bool> purchaseAvatar(String avatarId, int priceCoins) async {
    if (_profile.ownedAvatarIds.contains(avatarId)) return true;
    if (_profile.coins < priceCoins) return false;
    _emit(_profile.copyWith(
      coins: _profile.coins - priceCoins,
      ownedAvatarIds: [..._profile.ownedAvatarIds, avatarId],
      avatarId: avatarId,
    ));
    return true;
  }

  Future<bool> purchaseInitialSkin(String skinId, int priceCoins) async {
    if (_profile.ownedInitialSkinIds.contains(skinId)) return true;
    if (_profile.coins < priceCoins) return false;
    _emit(_profile.copyWith(
      coins: _profile.coins - priceCoins,
      ownedInitialSkinIds: [..._profile.ownedInitialSkinIds, skinId],
      initialSkinId: skinId,
    ));
    return true;
  }

  @override
  Future<bool> purchaseLife() async {
    final now = DateTime.now();
    final resolved = LivesLogic.resolve(
      lives: _profile.lives,
      nextLifeAt: _profile.nextLifeAt,
      now: now,
    );
    if (resolved.effectiveLives >= Progression.maxLives) return false;
    if (_profile.coins < Progression.lifeRefillPriceCoins) return false;

    final updatedLives = LivesLogic.onPurchase(
      lives: resolved.effectiveLives,
      nextLifeAt: resolved.nextLifeAt,
      now: now,
    );
    _emit(_profile.copyWith(
      coins: _profile.coins - Progression.lifeRefillPriceCoins,
      lives: updatedLives.lives,
      nextLifeAt: updatedLives.nextLifeAt,
    ));
    return true;
  }

  Future<bool> claimDaily() async {
    final now = DateTime.now();
    final last = _profile.lastDailyClaimAt;
    if (last != null && now.difference(last) < const Duration(hours: 24)) {
      return false;
    }
    final boost = PowerUpCatalog.todayDailyBoost(now.toUtc());
    var inv = PowerUpInventory.fromMap(_profile.powerUpInventory);
    inv = inv.withGrant(boost, PowerUpCatalog.dailyBoostQuantity);
    _emit(_profile.copyWith(
      coins: _profile.coins + 60,
      xp: _profile.xp + 40,
      lastDailyClaimAt: now,
      powerUpInventory: inv.toMap(),
    ));
    return true;
  }

  @override
  Future<bool> devResetDailyClaim() async {
    _emit(_profile.copyWith(clearLastDailyClaimAt: true));
    return true;
  }

  @override
  Future<bool> grantLifeFromAd() async {
    return _grantFreeLife();
  }

  @override
  Future<bool> refundLastCampaignLife() async {
    return _grantFreeLife();
  }

  bool _grantFreeLife() {
    final now = DateTime.now();
    final resolved = LivesLogic.resolve(
      lives: _profile.lives,
      nextLifeAt: _profile.nextLifeAt,
      now: now,
    );
    if (resolved.effectiveLives >= Progression.maxLives) return false;
    final updated = LivesLogic.onPurchase(
      lives: resolved.effectiveLives,
      nextLifeAt: resolved.nextLifeAt,
      now: now,
    );
    _emit(_profile.copyWith(
      lives: updated.lives,
      nextLifeAt: updated.nextLifeAt,
    ));
    return true;
  }

  @override
  Future<bool> purchasePowerUp(
    String powerUpId,
    int priceCoins, {
    int quantity = 1,
  }) async {
    if (_profile.coins < priceCoins) return false;
    var inv = PowerUpInventory.fromMap(_profile.powerUpInventory);
    final type = PowerUpTypeX.fromId(powerUpId);
    if (type == null) return false;
    inv = inv.withGrant(type, quantity);
    _emit(_profile.copyWith(
      coins: _profile.coins - priceCoins,
      powerUpInventory: inv.toMap(),
    ));
    return true;
  }

  @override
  Future<bool> consumePowerUp(String powerUpId, {int quantity = 1}) async {
    final type = PowerUpTypeX.fromId(powerUpId);
    if (type == null) return false;
    var inv = PowerUpInventory.fromMap(_profile.powerUpInventory);
    if (inv.countFor(type) < quantity) return false;
    inv = inv.withConsume(type, qty: quantity);
    _emit(_profile.copyWith(powerUpInventory: inv.toMap()));
    return true;
  }

  @override
  Future<void> grantPowerUp(String powerUpId, int quantity) async {
    final type = PowerUpTypeX.fromId(powerUpId);
    if (type == null) return;
    var inv = PowerUpInventory.fromMap(_profile.powerUpInventory);
    inv = inv.withGrant(type, quantity);
    _emit(_profile.copyWith(powerUpInventory: inv.toMap()));
  }

  @override
  Future<bool> claimRewardedAd() async {
    final now = DateTime.now();
    final last = _profile.lastRewardedAdAt;
    if (last != null && now.difference(last) < const Duration(minutes: 30)) {
      return false;
    }
    _emit(_profile.copyWith(
      coins: _profile.coins + 35,
      lastRewardedAdAt: now,
    ));
    return true;
  }

  @override
  Future<void> syncLives() async {
    final now = DateTime.now();
    final resolved = LivesLogic.resolve(
      lives: _profile.lives,
      nextLifeAt: _profile.nextLifeAt,
      now: now,
    );
    if (resolved.effectiveLives != _profile.lives ||
        resolved.nextLifeAt != _profile.nextLifeAt) {
      _emit(_profile.copyWith(
        lives: resolved.effectiveLives,
        nextLifeAt: resolved.nextLifeAt,
      ));
    }
  }

  /// Simulate authoritative match settlement in the backend.
  Future<void> settleMatch(
    MatchResult result, {
    bool consumeLife = false,
  }) async {
    final now = DateTime.now();
    final syncedLives = LivesLogic.resolve(
      lives: _profile.lives,
      nextLifeAt: _profile.nextLifeAt,
      now: now,
    );

    final win = result == MatchResult.win;
    final tie = result == MatchResult.tie;

    final deltaCoins = Progression.coinsForMatch(win: win, tie: tie);
    final deltaXp = Progression.xpForMatch(win: win, tie: tie);

    final newXp = _profile.xp + deltaXp;

    final newWins = _profile.wins + (win ? 1 : 0);
    final newLosses = _profile.losses + (result == MatchResult.loss ? 1 : 0);
    final newTies = _profile.ties + (tie ? 1 : 0);
    final newGames = _profile.gamesPlayed + 1;

    final newStreak =
        win ? _profile.winStreak + 1 : (tie ? _profile.winStreak : 0);
    final bestStreak =
        newStreak > _profile.bestWinStreak ? newStreak : _profile.bestWinStreak;

    var newRating = _profile.rating;
    if (win) newRating += 18;
    if (tie) newRating += 2;
    if (!win && !tie) newRating -= 18;
    if (newRating < 800) newRating = 800;

    final seasonBest = newRating > _profile.seasonBestRating
        ? newRating
        : _profile.seasonBestRating;

    var lives = syncedLives.effectiveLives;
    var nextLifeAt = syncedLives.nextLifeAt;
    if (consumeLife && result == MatchResult.loss) {
      final afterLoss =
          LivesLogic.onLoss(lives: lives, nextLifeAt: nextLifeAt, now: now);
      lives = afterLoss.lives;
      nextLifeAt = afterLoss.nextLifeAt;
    }

    _emit(_profile.copyWith(
      coins: _profile.coins + deltaCoins,
      xp: newXp,
      wins: newWins,
      dailyMissions: _profile.dailyMissions.forToday().copyWithBump(
        win: win,
        gamePlayed: true,
      ),
      losses: newLosses,
      ties: newTies,
      gamesPlayed: newGames,
      winStreak: newStreak,
      bestWinStreak: bestStreak,
      rating: newRating,
      seasonBestRating: seasonBest,
      seasonWins: _profile.seasonWins + (win ? 1 : 0),
      seasonLosses: _profile.seasonLosses +
          (result == MatchResult.loss ? 1 : 0),
      seasonTies: _profile.seasonTies + (tie ? 1 : 0),
      lives: lives,
      nextLifeAt: nextLifeAt,
    ));
  }

  @override
  Future<void> settleCampaignLevel({
    required String levelId,
    required int starsEarned,
    required int coinReward,
    required int xpReward,
    bool consumeLife = true,
    bool win = true,
    int boxesCaptured = 0,
    Map<String, int> powerUpRewards = const {},
  }) async {
    final now = DateTime.now();
    final syncedLives = LivesLogic.resolve(
      lives: _profile.lives,
      nextLifeAt: _profile.nextLifeAt,
      now: now,
    );

    final currentBest = _profile.campaignStars[levelId] ?? 0;
    Map<String, int> newStars;
    if (starsEarned > currentBest) {
      newStars = Map<String, int>.from(_profile.campaignStars)
        ..[levelId] = starsEarned;
    } else {
      newStars = _profile.campaignStars;
    }

    final newXp = _profile.xp + (win ? xpReward : xpReward ~/ 4);
    final newLevel = Progression.levelForStars(
      Progression.totalStarsFromMap(newStars),
    );

    var lives = syncedLives.effectiveLives;
    var nextLifeAt = syncedLives.nextLifeAt;
    if (consumeLife && !win) {
      final afterLoss =
          LivesLogic.onLoss(lives: lives, nextLifeAt: nextLifeAt, now: now);
      lives = afterLoss.lives;
      nextLifeAt = afterLoss.nextLifeAt;
    }

    var inv = PowerUpInventory.fromMap(_profile.powerUpInventory);
    if (win) {
      for (final entry in powerUpRewards.entries) {
        final type = PowerUpTypeX.fromId(entry.key);
        if (type != null) inv = inv.withGrant(type, entry.value);
      }
    }

    _emit(_profile.copyWith(
      coins: _profile.coins + (win ? coinReward : coinReward ~/ 4),
      xp: newXp,
      level: newLevel,
      gamesPlayed: _profile.gamesPlayed + 1,
      wins: _profile.wins + (win ? 1 : 0),
      losses: _profile.losses + (win ? 0 : 1),
      lives: lives,
      nextLifeAt: nextLifeAt,
      campaignStars: newStars,
      lastCampaignLevelId: levelId,
      dailyMissions: _profile.dailyMissions.forToday().copyWithBump(
        win: win,
        gamePlayed: true,
        boxesCaptured: boxesCaptured,
      ),
      powerUpInventory: inv.toMap(),
    ));
  }

  @override
  Future<void> settleDailyPuzzle({
    required String levelId,
    required bool win,
    int boxesCaptured = 0,
  }) async {
    if (!win) return;
    final today = DailyMissionProgress.todayUtc();
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final streak = _profile.dailyPuzzleDate == yesterdayKey
        ? _profile.dailyPuzzleStreak + 1
        : (_profile.dailyPuzzleDate == today ? _profile.dailyPuzzleStreak : 1);

    _emit(_profile.copyWith(
      coins: _profile.coins + 50,
      dailyPuzzleDate: today,
      dailyPuzzleLevelId: levelId,
      dailyPuzzleCompleted: true,
      dailyPuzzleStreak: streak,
      dailyMissions: _profile.dailyMissions.forToday().copyWithBump(
        win: true,
        gamePlayed: true,
        boxesCaptured: boxesCaptured,
      ),
    ));
  }

  @override
  Future<bool> claimDailyMission(String missionId) async {
    final targets = <String, ({int target, int coins})>{
      'win_matches': (target: 3, coins: 45),
      'play_games': (target: 4, coins: 60),
      'capture_boxes': (target: 15, coins: 35),
    };
    final spec = targets[missionId];
    if (spec == null) return false;
    final progress = _profile.dailyMissions.forToday();
    if (progress.isClaimed(missionId)) return false;
    if (progress.progressFor(missionId) < spec.target) return false;

    _emit(_profile.copyWith(
      coins: _profile.coins + spec.coins,
      dailyMissions: progress.withClaimed(missionId),
    ));
    return true;
  }

  @override
  Future<void> recordMatch({
    required MatchResult result,
    required String modeLabel,
    required String opponentLabel,
  }) async {
    final record = RecentMatchRecord(
      id: 'mock_${_matches.length}',
      outcome: result,
      modeLabel: modeLabel,
      opponentLabel: opponentLabel,
      playedAt: DateTime.now(),
    );
    _matches.insert(0, record);
    if (_matches.length > 10) _matches.removeLast();
    _matchesController.add(List.unmodifiable(_matches));
  }

  @override
  Stream<List<RecentMatchRecord>> watchRecentMatches({int limit = 10}) async* {
    yield _matches.take(limit).toList();
    yield* _matchesController.stream.map((list) => list.take(limit).toList());
  }

  void _emit(UserProfile p) {
    _profile = p;
    _controller.add(p);
  }

  static UserProfile _defaultProfile() {
    final seasonId = RankSystem.currentSeasonId(DateTime.now());
    return UserProfile(
      uid: 'mock',
      displayName: 'Player',
      coins: 200,
      xp: 0,
      level: 1,
      wins: 0,
      losses: 0,
      ties: 0,
      gamesPlayed: 0,
      winStreak: 0,
      bestWinStreak: 0,
      seasonId: seasonId,
      rating: 1000,
      seasonBestRating: 1000,
      seasonWins: 0,
      seasonLosses: 0,
      seasonTies: 0,
      themeId: 'theme_neon_default',
      avatarId: 'avatar_orb_cyan',
      initialSkinId: 'initial_skin_classic',
      removeAds: false,
      ownedThemeIds: const ['theme_neon_default'],
      ownedAvatarIds: const ['avatar_orb_cyan'],
      ownedInitialSkinIds: const ['initial_skin_classic'],
      lives: Progression.maxLives,
      nextLifeAt: null,
      lastDailyClaimAt: null,
      lastRewardedAdAt: null,
      dailyMissions: DailyMissionProgress(
        date: DailyMissionProgress.todayUtc(),
        wins: 0,
        games: 0,
        boxes: 0,
        claimedIds: const {},
      ),
    );
  }
}
