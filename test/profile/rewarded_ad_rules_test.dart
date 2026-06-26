import 'package:dot_clash/features/profile/domain/rewarded_ad_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardedAdRules', () {
    test('canClaimRewardedCoins when never claimed', () {
      expect(RewardedAdRules.canClaimRewardedCoins(null), isTrue);
    });

    test('blocks coins within 30 minute cooldown', () {
      final now = DateTime(2026, 6, 23, 12, 0);
      final last = now.subtract(const Duration(minutes: 10));

      expect(RewardedAdRules.canClaimRewardedCoins(last, now), isFalse);
      expect(
        RewardedAdRules.coinCooldownRemaining(last, now),
        const Duration(minutes: 20),
      );
    });

    test('allows coins after cooldown expires', () {
      final now = DateTime(2026, 6, 23, 12, 0);
      final last = now.subtract(const Duration(minutes: 31));

      expect(RewardedAdRules.canClaimRewardedCoins(last, now), isTrue);
    });

    test('formatCooldown uses minutes then seconds', () {
      expect(
        RewardedAdRules.formatCooldown(const Duration(minutes: 2, seconds: 5)),
        '2m',
      );
      expect(
        RewardedAdRules.formatCooldown(const Duration(seconds: 45)),
        '45s',
      );
    });
  });
}
