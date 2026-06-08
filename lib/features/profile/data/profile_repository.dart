import '../domain/user_profile.dart';

enum MatchResult { win, loss, tie }

abstract class ProfileRepository {
  Stream<UserProfile> watchProfile();

  Future<void> setDisplayName(String name);
  Future<void> equipTheme(String themeId);
  Future<void> equipAvatar(String avatarId);
  Future<void> equipInitialSkin(String skinId);

  Future<bool> purchaseTheme(String themeId, int priceCoins);
  Future<bool> purchaseAvatar(String avatarId, int priceCoins);
  Future<bool> purchaseInitialSkin(String skinId, int priceCoins);
  Future<bool> purchaseLife();

  Future<bool> claimDaily();
  Future<bool> devResetDailyClaim();
  Future<bool> claimRewardedAd();
  Future<bool> grantLifeFromAd();
  Future<bool> refundLastCampaignLife();

  Future<bool> purchasePowerUp(String powerUpId, int priceCoins,
      {int quantity = 1});
  Future<bool> consumePowerUp(String powerUpId, {int quantity = 1});
  Future<void> grantPowerUp(String powerUpId, int quantity);

  Future<void> syncLives();
  Future<void> settleMatch(
    MatchResult result, {
    bool consumeLife = false,
  });

  /// Settle a campaign level. Grants coins/XP and updates best star count.
  /// Stars improve only when [starsEarned] > current best for [levelId].
  Future<void> settleCampaignLevel({
    required String levelId,
    required int starsEarned,
    required int coinReward,
    required int xpReward,
    bool consumeLife = true,
    bool win = true,
    int boxesCaptured = 0,
    Map<String, int> powerUpRewards = const {},
  });

  Future<void> settleDailyPuzzle({
    required String levelId,
    required bool win,
    int boxesCaptured = 0,
  });

  Future<bool> claimDailyMission(String missionId);

  /// Verifies Remove Ads with the store, then sets [UserProfile.removeAds] server-side.
  Future<bool> verifyRemoveAdsPurchase({
    required String platform,
    required String productId,
    String? packageName,
    String? purchaseToken,
    String? verificationData,
    String? localVerificationData,
  });

  /// Dev/mock only — prod must use [verifyRemoveAdsPurchase].
  Future<bool> grantRemoveAds();

  Future<void> recordMatch({
    required MatchResult result,
    required String modeLabel,
    required String opponentLabel,
  });

  Stream<List<RecentMatchRecord>> watchRecentMatches({int limit = 10});
}

class RecentMatchRecord {
  const RecentMatchRecord({
    required this.id,
    required this.outcome,
    required this.modeLabel,
    required this.opponentLabel,
    required this.playedAt,
  });

  final String id;
  final MatchResult outcome;
  final String modeLabel;
  final String opponentLabel;
  final DateTime playedAt;
}
