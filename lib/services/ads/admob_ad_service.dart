import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/env/app_env.dart';
import '../analytics/analytics_service.dart';
import 'ad_consent_service.dart';
import 'ad_placement.dart';
import 'ad_service.dart';
import 'reward_signal_wait.dart';

/// Google Mobile Ads — test units when [AppEnv.usesTestAdUnits] (dev or BETA_ADS).
///
/// Rewarded flow (dev + prod): [RewardedAd.show] starts native presentation;
/// full-screen callbacks tell us when the ad closes. [onUserEarnedReward] is
/// the earn signal. We wait for the ad to close, then wait for that hook
/// (primary + grace) before reloading the ad. [AdRewardRouter] grants by
/// placement.
class AdMobAdService implements AdService {
  static const Duration _rewardSignalTotalTimeout = Duration(seconds: 11);
  static const Duration _rewardSignalPrimaryWindow = Duration(seconds: 8);

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _matchesSinceLast = 0;
  bool _rewardedShowInProgress = false;

  final _consent = AdConsentService.instance;

  @override
  Future<void> init() async {
    await _consent.gatherConsentIfNeeded();
    final canRequest = await _consent.canRequestAds();
    debugPrint(
      '[AdConsent] canRequestAds=$canRequest '
      'flavor=${AppEnv.flavor} testUnits=${AppEnv.usesTestAdUnits}',
    );
    if (!canRequest) {
      debugPrint('[AdMobAdService] Ads blocked until consent (UMP).');
      return;
    }
    await MobileAds.instance.initialize();
    debugPrint(
      '[AdMobAdService] initialized interstitial=$_interstitialId '
      'rewarded=$_rewardedId',
    );
    _loadInterstitial();
    _loadRewarded();
  }

  AdRequest get _adRequest => _consent.adRequest();

  static String get _interstitialId => Platform.isAndroid
      ? AppEnv.interstitialAdUnitAndroid
      : AppEnv.interstitialAdUnitIos;

  static String get _rewardedId => Platform.isAndroid
      ? AppEnv.rewardedAdUnitAndroid
      : AppEnv.rewardedAdUnitIos;

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: _adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              _interstitial = null;
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              _interstitial = null;
              _loadInterstitial();
            },
          );
          _interstitial = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint(
            '[AdMobAdService] Interstitial failed: '
            'code=${err.code} domain=${err.domain} message=${err.message} '
            'unit=$_interstitialId',
          );
        },
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: _adRequest,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              _scheduleRewardedReload();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              _scheduleRewardedReload();
            },
          );
          _rewarded = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint(
            '[AdMobAdService] Rewarded failed: '
            'code=${err.code} domain=${err.domain} message=${err.message} '
            'unit=$_rewardedId',
          );
        },
      ),
    );
  }

  @override
  bool get isRewardedReady => _rewarded != null;

  void _scheduleRewardedReload() {
    if (_rewardedShowInProgress) return;
    _rewarded = null;
    _loadRewarded();
  }

  void _finishRewardedShow() {
    _rewardedShowInProgress = false;
    _rewarded = null;
    _loadRewarded();
  }

  @override
  Future<AdShowResult> showRewarded(
    AdPlacement placement, {
    void Function()? onDismissed,
  }) async {
    final ad = _rewarded;
    if (ad == null) return AdShowResult.unavailable;

    final rewardEarned = Completer<void>();
    final dismissed = Completer<void>();
    final failedToShow = Completer<void>();
    final placementName = placement.name;

    void onUserEarnedReward(AdWithoutView _, RewardItem reward) {
      debugPrint(
        '[AdMobAdService] onUserEarnedReward ($placementName): '
        '${reward.amount} ${reward.type} — SDK label only; '
        'in-game grant is by placement in AdRewardRouter',
      );
      if (!rewardEarned.isCompleted) {
        rewardEarned.complete();
      }
    }

    _rewardedShowInProgress = true;
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (_, err) {
        debugPrint(
          '[AdMobAdService] Rewarded show failed ($placementName): $err',
        );
        if (!failedToShow.isCompleted) failedToShow.complete();
      },
    );

    var showSucceeded = false;
    try {
      await ad.show(onUserEarnedReward: onUserEarnedReward);
      showSucceeded = true;
    } catch (e, st) {
      debugPrint('[AdMobAdService] showRewarded error: $e\n$st');
    }

    late final AdShowResult result;
    if (!showSucceeded) {
      result = AdShowResult.unavailable;
    } else {
      final lifecycleResult = await waitForRewardedShowLifecycle(
        dismissed: dismissed.future,
        failedToShow: failedToShow.future,
      );
      if (lifecycleResult == RewardedShowLifecycleResult.failedToShow) {
        _finishRewardedShow();
        return AdShowResult.unavailable;
      }
      if (lifecycleResult == RewardedShowLifecycleResult.timedOut) {
        debugPrint(
          '[AdMobAdService] Rewarded lifecycle timed out '
          '($placementName) — not granting',
        );
        _finishRewardedShow();
        return AdShowResult.cancelled;
      }

      onDismissed?.call();

      await yieldForAdMobRewardCallback();

      final waitStartedAt = DateTime.now();
      var earned = await waitForRewardEarnedSignal(
        () => rewardEarned.isCompleted,
        totalTimeout: _rewardSignalTotalTimeout,
      );
      if (!earned) {
        // Platform channel may deliver onUserEarnedReward one tick after polling ends.
        await yieldForAdMobRewardCallback();
        earned = rewardEarned.isCompleted;
      }
      if (!earned) {
        debugPrint(
          '[AdMobAdService] No reward signal ($placementName) — not granting',
        );
        result = AdShowResult.cancelled;
      } else {
        final usedGrace = DateTime.now().difference(waitStartedAt) >
            _rewardSignalPrimaryWindow;
        debugPrint(
          '[AdMobAdService] Reward signal OK ($placementName'
          '${usedGrace ? ', late grace' : ''}) — AdRewardRouter grants',
        );
        result = AdShowResult.completed;
      }
    }

    _finishRewardedShow();
    return result;
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return false;

    final shown = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        AnalyticsService.instance.logAdImpression(
          AdPlacement.interstitial.analyticsName,
        );
        if (!shown.isCompleted) shown.complete(true);
      },
      onAdDismissedFullScreenContent: (_) {
        if (!shown.isCompleted) shown.complete(false);
        _interstitial = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (_, err) {
        debugPrint('[AdMobAdService] Interstitial show failed: $err');
        if (!shown.isCompleted) shown.complete(false);
        _interstitial = null;
        _loadInterstitial();
      },
    );

    _interstitial = null;
    try {
      await ad.show();
    } catch (e, st) {
      debugPrint('[AdMobAdService] showInterstitial error: $e\n$st');
      if (!shown.isCompleted) shown.complete(false);
      _loadInterstitial();
      return false;
    }

    try {
      return await shown.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<bool> onMatchFinished({required bool removeAds}) async {
    if (removeAds) return false;
    _matchesSinceLast++;
    if (_matchesSinceLast < AppEnv.adFrequencyMatches) return false;
    _matchesSinceLast = 0;
    return showInterstitial();
  }

  @override
  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
  }
}
