/// Client rules for rewarded-ad grants (must match [functions/src/economy.ts]).
abstract final class RewardedAdRules {
  static const Duration coinCooldown = Duration(minutes: 30);
  static const int rewardedCoinGrant = 35;

  static Duration? coinCooldownRemaining(
    DateTime? lastRewardedAdAt, [
    DateTime? now,
  ]) {
    final at = lastRewardedAdAt;
    if (at == null) return null;
    final elapsed = (now ?? DateTime.now()).difference(at);
    if (elapsed >= coinCooldown) return null;
    return coinCooldown - elapsed;
  }

  static bool canClaimRewardedCoins(
    DateTime? lastRewardedAdAt, [
    DateTime? now,
  ]) =>
      coinCooldownRemaining(lastRewardedAdAt, now) == null;

  static String formatCooldown(Duration remaining) {
    final minutes = remaining.inMinutes;
    if (minutes >= 1) return '${minutes}m';
    final seconds = remaining.inSeconds.clamp(1, 59);
    return '${seconds}s';
  }
}
