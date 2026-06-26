import 'dart:async';

enum RewardedShowLifecycleResult { dismissed, failedToShow, timedOut }

/// Waits for AdMob [onUserEarnedReward] after a rewarded ad closes.
///
/// Platform channels can deliver the earn callback after [RewardedAd.show]
/// returns, sometimes after [Future.timeout] listeners have already given up.
/// Poll [isCompleted] until [totalTimeout] instead of relying on future timeouts.
Future<bool> waitForRewardEarnedSignal(
  bool Function() isCompleted, {
  Duration totalTimeout = const Duration(seconds: 11),
  Duration pollInterval = const Duration(milliseconds: 50),
}) async {
  if (isCompleted()) return true;

  final deadline = DateTime.now().add(totalTimeout);
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(pollInterval);
    if (isCompleted()) return true;
  }
  return isCompleted();
}

/// Yields so platform-channel callbacks queued during [RewardedAd.show] can run.
Future<void> yieldForAdMobRewardCallback() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

/// Waits for the native rewarded-ad surface to finish.
///
/// [RewardedAd.show] starts the native presentation, but the returned future is
/// not a reliable "ad has closed" signal across SDK/platform timing. Use the
/// full-screen callbacks to decide when it is safe to evaluate the reward hook.
Future<RewardedShowLifecycleResult> waitForRewardedShowLifecycle({
  required Future<void> dismissed,
  required Future<void> failedToShow,
  Duration timeout = const Duration(minutes: 2),
}) {
  return Future.any([
    dismissed.then((_) => RewardedShowLifecycleResult.dismissed),
    failedToShow.then((_) => RewardedShowLifecycleResult.failedToShow),
    Future<void>.delayed(timeout)
        .then((_) => RewardedShowLifecycleResult.timedOut),
  ]);
}
