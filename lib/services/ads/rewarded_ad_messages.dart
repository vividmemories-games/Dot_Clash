import '../../features/profile/domain/rewarded_ad_rules.dart';

/// User-facing copy when a rewarded ad does not grant a reward.
abstract final class RewardedAdMessages {
  static String shopCoinsFailure({required DateTime? lastRewardedAdAt}) {
    final remaining = RewardedAdRules.coinCooldownRemaining(lastRewardedAdAt);
    if (remaining != null) {
      return 'Coin ad available in ${RewardedAdRules.formatCooldown(remaining)}.';
    }
    return 'Watch the full ad to earn coins.';
  }

  static String shopLifeFailure({
    required bool livesFull,
    required bool dailyCapReached,
  }) {
    if (livesFull) return 'Lives are already full.';
    if (dailyCapReached) return 'Daily life ad limit reached (3/day).';
    return 'Watch the full ad to earn a life.';
  }

  static String retryLifeFailure({required bool dailyRescueCapReached}) {
    if (dailyRescueCapReached) {
      return 'Daily rescue ad limit reached (5/day).';
    }
    return 'Watch the full ad to retry this level.';
  }
}
