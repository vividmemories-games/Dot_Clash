import '../domain/user_profile.dart';
import '../domain/rewarded_ad_rules.dart';

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
  Future<bool> claimRewardedAd({required String grantId});
  Future<bool> grantLifeFromAd({
    required String grantId,
    String kind = AdGrantKinds.lifeRefill,
  });
  Future<bool> refundLastCampaignLife({required String grantId});

  /// Forfeit a campaign level in progress (mid-match leave). Idempotent per
  /// [forfeitId] — safe to retry the same abandon attempt.
  Future<bool> forfeitCampaignLevel({
    required String levelId,
    required String forfeitId,
  });

  Future<bool> purchasePowerUp(String powerUpId, int priceCoins,
      {int quantity = 1});
  Future<bool> consumePowerUp(String powerUpId, {int quantity = 1});
  Future<void> grantPowerUp(String powerUpId, int quantity);

  Future<void> syncLives();
  Future<void> settleMatch(
    MatchResult result, {
    bool consumeLife = false,
    required String matchId,
  });

  /// Settle a campaign level. Grants coins/XP and updates best star count.
  /// Stars improve only when [starsEarned] > current best for [levelId].
  /// Idempotent per [settlementId] on the server.
  Future<void> settleCampaignLevel({
    required String levelId,
    required String settlementId,
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

  /// Server-authoritative challenge settlement (stats + match history).
  Future<void> recordChallengeMatch({
    required String code,
    required MatchResult result,
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
    this.challengeCode,
    this.opponentUid,
  });

  final String id;
  final MatchResult outcome;
  final String modeLabel;
  final String opponentLabel;
  final DateTime playedAt;
  final String? challengeCode;
  final String? opponentUid;
}
