import 'dart:async';

import 'package:dot_clash/services/ads/reward_signal_wait.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('waitForRewardEarnedSignal', () {
    test('returns true when already completed', () async {
      const completed = true;

      final earned = await waitForRewardEarnedSignal(
        () => completed,
        totalTimeout: const Duration(milliseconds: 50),
        pollInterval: const Duration(milliseconds: 10),
      );

      expect(earned, isTrue);
    });

    test('returns true when reward completes during wait', () async {
      var completed = false;

      final earnedFuture = waitForRewardEarnedSignal(
        () => completed,
        totalTimeout: const Duration(milliseconds: 200),
        pollInterval: const Duration(milliseconds: 10),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      completed = true;

      expect(await earnedFuture, isTrue);
    });

    test('returns true when reward completes late in grace window', () async {
      var completed = false;

      final earnedFuture = waitForRewardEarnedSignal(
        () => completed,
        totalTimeout: const Duration(milliseconds: 250),
        pollInterval: const Duration(milliseconds: 10),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      completed = true;

      expect(await earnedFuture, isTrue);
    });

    test('returns false when reward never completes', () async {
      final earned = await waitForRewardEarnedSignal(
        () => false,
        totalTimeout: const Duration(milliseconds: 40),
        pollInterval: const Duration(milliseconds: 10),
      );

      expect(earned, isFalse);
    });
  });

  group('waitForRewardedShowLifecycle', () {
    test('returns dismissed when the ad closes', () async {
      final dismissed = Completer<void>();
      final failedToShow = Completer<void>();

      final resultFuture = waitForRewardedShowLifecycle(
        dismissed: dismissed.future,
        failedToShow: failedToShow.future,
        timeout: const Duration(milliseconds: 100),
      );

      dismissed.complete();

      expect(
        await resultFuture,
        RewardedShowLifecycleResult.dismissed,
      );
    });

    test('returns failedToShow when the native SDK rejects presentation',
        () async {
      final dismissed = Completer<void>();
      final failedToShow = Completer<void>();

      final resultFuture = waitForRewardedShowLifecycle(
        dismissed: dismissed.future,
        failedToShow: failedToShow.future,
        timeout: const Duration(milliseconds: 100),
      );

      failedToShow.complete();

      expect(
        await resultFuture,
        RewardedShowLifecycleResult.failedToShow,
      );
    });

    test('returns timedOut when no full-screen callback arrives', () async {
      final result = await waitForRewardedShowLifecycle(
        dismissed: Completer<void>().future,
        failedToShow: Completer<void>().future,
        timeout: const Duration(milliseconds: 10),
      );

      expect(result, RewardedShowLifecycleResult.timedOut);
    });
  });
}
