import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/powerups/domain/power_up.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/domain/lives_logic.dart';
import '../../features/profile/domain/rewarded_ad_rules.dart';
import '../../features/profile/providers/lives_provider.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../analytics/analytics_service.dart';
import 'ad_placement.dart';
import 'ad_service.dart';
import 'ad_service_provider.dart';

/// Routes rewarded placements to AdMob, then grants in-game rewards.
///
/// Contract (dev + prod): [AdService.showRewarded] returns [AdShowResult.completed]
/// only after AdMob [onUserEarnedReward]. This router then runs the matching
/// [ProfileRepository] grant — never AdMob [RewardItem] amounts.
class AdRewardRouter {
  AdRewardRouter(this._ref);

  final Ref _ref;

  AdService get _ads => _ref.read(adServiceProvider);
  ProfileRepository get _repo => _ref.read(profileRepositoryProvider);

  int _lifeAdsToday = 0;
  int _rescueAdsToday = 0;
  String? _lifeAdsDate;
  String? _rescueAdsDate;
  bool _rescueUsedThisMatch = false;

  static const maxLifeAdsPerDay = 3;
  static const maxRescueAdsPerDay = 5;

  void resetMatchRescueFlag() => _rescueUsedThisMatch = false;

  bool get canOfferRescueAd =>
      !_rescueUsedThisMatch && _rescueCountToday() < maxRescueAdsPerDay;

  void _rollDailyCounters() {
    final today = dailyMissionProgressToday();
    if (_lifeAdsDate != today) {
      _lifeAdsDate = today;
      _lifeAdsToday = 0;
    }
    if (_rescueAdsDate != today) {
      _rescueAdsDate = today;
      _rescueAdsToday = 0;
    }
  }

  int _rescueCountToday() {
    _rollDailyCounters();
    return _rescueAdsToday;
  }

  bool get isLifeAdDailyCapReached {
    _rollDailyCounters();
    return _lifeAdsToday >= maxLifeAdsPerDay;
  }

  bool get isRescueAdDailyCapReached {
    _rollDailyCounters();
    return _rescueAdsToday >= maxRescueAdsPerDay;
  }

  bool canShowRewardedShopCoins(DateTime? lastRewardedAdAt) =>
      RewardedAdRules.canClaimRewardedCoins(lastRewardedAdAt);

  bool canShowRewardedLifeAd(LivesSnapshot lives) =>
      !lives.isFull && !isLifeAdDailyCapReached;

  /// AdMob earn signal → analytics → profile grant.
  Future<bool> _showRewardedAndGrant({
    required AdPlacement placement,
    required Future<bool> Function() grant,
    void Function()? onGrantSuccess,
  }) async {
    final result = await _ads.showRewarded(placement);
    if (result != AdShowResult.completed) {
      debugPrint(
        '[AdReward] ${placement.name}: ad not completed ($result)',
      );
      return false;
    }

    AnalyticsService.instance.logAdImpression(placement.analyticsName);

    final bool granted;
    try {
      granted = await grant();
    } catch (e, st) {
      // The grant callable can throw on prod (e.g. App Check / network); never
      // let that escape as an unhandled exception. Return false so the caller
      // shows a graceful retry message, and crucially do NOT call
      // onGrantSuccess — the rescue/daily counters stay un-incremented so the
      // user can try the reward again rather than silently losing the ad watch.
      debugPrint('[AdReward] ${placement.name}: in-game grant threw — $e');
      await AnalyticsService.instance.recordError(e, st);
      return false;
    }
    if (granted) {
      onGrantSuccess?.call();
    } else {
      debugPrint('[AdReward] ${placement.name}: in-game grant returned false');
    }
    return granted;
  }

  Future<bool> showRewardedLifeAd() async {
    _rollDailyCounters();
    if (isLifeAdDailyCapReached) return false;

    final lives = _ref.read(livesSnapshotProvider);
    if (lives.isFull) return false;

    return _showRewardedAndGrant(
      placement: AdPlacement.lifeRefill,
      grant: _repo.grantLifeFromAd,
      onGrantSuccess: () => _lifeAdsToday++,
    );
  }

  Future<bool> showRewardedShopCoins() async {
    final lastRewardedAt =
        _ref.read(profileProvider).valueOrNull?.lastRewardedAdAt;
    if (!canShowRewardedShopCoins(lastRewardedAt)) return false;

    return _showRewardedAndGrant(
      placement: AdPlacement.shopCoins,
      grant: _repo.claimRewardedAd,
    );
  }

  Future<bool> showRewardedRetry() async {
    if (!canOfferRescueAd) return false;

    return _showRewardedAndGrant(
      placement: AdPlacement.lossRetry,
      grant: _repo.refundLastCampaignLife,
      onGrantSuccess: () {
        _rescueUsedThisMatch = true;
        _rescueAdsToday++;
      },
    );
  }

  Future<bool> showRewardedRiposte() async {
    if (!canOfferRescueAd) return false;

    return _showRewardedAndGrant(
      placement: AdPlacement.riposteRescue,
      grant: () =>
          _repo.grantPowerUp(PowerUpType.riposte.id, 1).then((_) => true),
      onGrantSuccess: () {
        _rescueUsedThisMatch = true;
        _rescueAdsToday++;
      },
    );
  }

  Future<bool> showRewardedExtraTurns({
    bool lowTurns = false,
    bool grantInventory = true,
  }) async {
    if (!canOfferRescueAd) return false;

    final placement =
        lowTurns ? AdPlacement.extraTurnsLow : AdPlacement.extraTurns;

    if (!grantInventory) {
      final result = await _ads.showRewarded(placement);
      if (result != AdShowResult.completed) return false;
      _rescueUsedThisMatch = true;
      _rescueAdsToday++;
      AnalyticsService.instance.logAdImpression(placement.analyticsName);
      return true;
    }

    return _showRewardedAndGrant(
      placement: placement,
      grant: () =>
          _repo.grantPowerUp(PowerUpType.extraTurns.id, 1).then((_) => true),
      onGrantSuccess: () {
        _rescueUsedThisMatch = true;
        _rescueAdsToday++;
      },
    );
  }

  /// Post-match interstitial (respects remove-ads and frequency cap).
  Future<void> handleMatchFinished({required bool removeAds}) async {
    await _ads.onMatchFinished(removeAds: removeAds);
  }
}

/// UTC yyyy-MM-dd for daily ad caps.
String dailyMissionProgressToday() {
  final now = DateTime.now().toUtc();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

final adRewardRouterProvider = Provider<AdRewardRouter>(AdRewardRouter.new);
