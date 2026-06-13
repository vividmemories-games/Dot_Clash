import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Analytics + Crashlytics.
/// All event names follow snake_case as required by Firebase.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;

  void init() {
    try {
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;
    } catch (e) {
      debugPrint('[Analytics] Not initialised: $e');
    }
  }

  // ── User ───────────────────────────────────────────────────────────────────

  Future<void> setUserId(String? uid) async {
    await _analytics?.setUserId(id: uid);
    if (uid != null && uid.isNotEmpty) {
      await _crashlytics?.setUserIdentifier(uid);
    }
  }

  // ── Screens ────────────────────────────────────────────────────────────────

  Future<void> logScreen(String name) async {
    await _analytics?.logScreenView(screenName: name);
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  Future<void> logOnboardingComplete() async {
    await _analytics?.logEvent(name: 'onboarding_complete');
  }

  // ── Tutorial ──────────────────────────────────────────────────────────────

  Future<void> logTutorialBegin({required String levelId}) async {
    await _analytics?.logEvent(
      name: 'tutorial_begin',
      parameters: {'level_id': levelId},
    );
  }

  Future<void> logTutorialStep({
    required String levelId,
    required String stepId,
    required int stepIndex,
  }) async {
    await _analytics?.logEvent(
      name: 'tutorial_step',
      parameters: {
        'level_id': levelId,
        'step_id': stepId,
        'step_index': stepIndex,
      },
    );
  }

  Future<void> logTutorialSkip({required String levelId}) async {
    await _analytics?.logEvent(
      name: 'tutorial_skip',
      parameters: {'level_id': levelId},
    );
  }

  Future<void> logTutorialComplete({required bool skipped}) async {
    await _analytics?.logEvent(
      name: 'tutorial_complete',
      parameters: {'skipped': skipped ? 1 : 0},
    );
  }

  // ── Home FTUE tour ────────────────────────────────────────────────────────

  Future<void> logHomeTourBegin() async {
    await _analytics?.logEvent(name: 'home_tour_begin');
  }

  Future<void> logHomeTourStep({
    required String stepId,
    required int stepIndex,
    required String targetId,
  }) async {
    await _analytics?.logEvent(
      name: 'home_tour_step',
      parameters: {
        'step_id': stepId,
        'step_index': stepIndex,
        'target_id': targetId,
      },
    );
  }

  Future<void> logHomeTourSkip() async {
    await _analytics?.logEvent(name: 'home_tour_skip');
  }

  Future<void> logHomeTourComplete() async {
    await _analytics?.logEvent(name: 'home_tour_complete');
  }

  // ── Campaign FTUE ─────────────────────────────────────────────────────────

  Future<void> logCampaignFtueBegin({required String levelId}) async {
    await _analytics?.logEvent(
      name: 'campaign_ftue_begin',
      parameters: {'level_id': levelId},
    );
  }

  Future<void> logCampaignFtueStep({
    required String levelId,
    required String stepId,
    required int stepIndex,
    required String targetId,
  }) async {
    await _analytics?.logEvent(
      name: 'campaign_ftue_step',
      parameters: {
        'level_id': levelId,
        'step_id': stepId,
        'step_index': stepIndex,
        'target_id': targetId,
      },
    );
  }

  Future<void> logCampaignFtueSkip({required String levelId}) async {
    await _analytics?.logEvent(
      name: 'campaign_ftue_skip',
      parameters: {'level_id': levelId},
    );
  }

  Future<void> logCampaignFtueComplete({required bool skipped}) async {
    await _analytics?.logEvent(
      name: 'campaign_ftue_complete',
      parameters: {'skipped': skipped ? 1 : 0},
    );
  }

  // ── Game events ────────────────────────────────────────────────────────────

  Future<void> logMatchStart({
    required String mode,
    required int boardSize,
  }) async {
    await _analytics?.logEvent(
      name: 'match_start',
      parameters: {'mode': mode, 'board_size': boardSize},
    );
  }

  Future<void> logMatchEnd({
    required String mode,
    required String result, // 'win' | 'loss' | 'tie'
    required int moveCount,
    required int boardSize,
  }) async {
    await _analytics?.logEvent(
      name: 'match_end',
      parameters: {
        'mode': mode,
        'result': result,
        'move_count': moveCount,
        'board_size': boardSize,
      },
    );
  }

  // ── Monetization ──────────────────────────────────────────────────────────

  Future<void> logAdImpression(String adType) async {
    await _analytics?.logAdImpression(
      adPlatform: 'admob',
      adFormat: adType,
      adUnitName: adType,
    );
  }

  Future<void> logIapPurchase({
    required String productId,
    required double price,
    required String currency,
  }) async {
    await _analytics?.logPurchase(
      currency: currency,
      value: price,
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productId,
          price: price,
        ),
      ],
    );
  }

  // ── Campaign ──────────────────────────────────────────────────────────────

  Future<void> logCampaignLevelStart({
    required String levelId,
    required int worldId,
    required int levelIndex,
    required bool isBoss,
  }) async {
    await _analytics?.logEvent(
      name: 'campaign_level_start',
      parameters: {
        'level_id': levelId,
        'world_id': worldId,
        'level_index': levelIndex,
        'is_boss': isBoss ? 1 : 0,
      },
    );
  }

  Future<void> logCampaignLevelComplete({
    required String levelId,
    required int worldId,
    required int levelIndex,
    required int starsEarned,
    required bool isBoss,
    required bool humanWon,
  }) async {
    await _analytics?.logEvent(
      name: 'campaign_level_complete',
      parameters: {
        'level_id': levelId,
        'world_id': worldId,
        'level_index': levelIndex,
        'stars_earned': starsEarned,
        'is_boss': isBoss ? 1 : 0,
        'human_won': humanWon ? 1 : 0,
      },
    );
  }

  Future<void> logStarsEarned({
    required String levelId,
    required int totalStars,
  }) async {
    await _analytics?.logEvent(
      name: 'stars_earned',
      parameters: {
        'level_id': levelId,
        'total_stars': totalStars,
      },
    );
  }

  // ── Challenge ─────────────────────────────────────────────────────────────

  Future<void> logChallengeStarted({required String code}) async {
    await _analytics?.logEvent(
      name: 'challenge_started',
      parameters: {'challenge_code': code},
    );
  }

  Future<void> logChallengeFinished({
    required String code,
    required String result,
    required int moveCount,
  }) async {
    await _analytics?.logEvent(
      name: 'challenge_finished',
      parameters: {
        'challenge_code': code,
        'result': result,
        'move_count': moveCount,
      },
    );
  }

  // ── Errors ────────────────────────────────────────────────────────────────

  Future<void> recordError(Object error, StackTrace? stack) async {
    await _crashlytics?.recordError(error, stack);
    debugPrint('[Error] $error\n$stack');
  }
}
