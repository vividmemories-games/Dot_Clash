import 'ad_placement.dart';

enum AdShowResult { completed, cancelled, unavailable }

abstract class AdService {
  Future<void> init();
  bool get isRewardedReady;

  /// Shows a rewarded ad. Returns [AdShowResult.completed] only after AdMob
  /// [onUserEarnedReward] (same behavior in dev test units and prod).
  ///
  /// [onDismissed] runs when the full-screen ad closes (before the earn signal
  /// is confirmed and before the router grants the in-game reward).
  Future<AdShowResult> showRewarded(
    AdPlacement placement, {
    void Function()? onDismissed,
  });

  /// Returns true when an interstitial was displayed.
  Future<bool> showInterstitial();

  /// Returns true when an interstitial was displayed (every N matches).
  Future<bool> onMatchFinished({required bool removeAds});
  void dispose();
}
