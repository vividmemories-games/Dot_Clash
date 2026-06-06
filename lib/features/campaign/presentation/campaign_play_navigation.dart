import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../providers/campaign_play_ready_provider.dart';
import '../../tutorial/presentation/coach_tour_target.dart';
import '../../tutorial/providers/coach_tour_provider.dart';

/// Exits an in-progress campaign level (and any modal above it) back to the map.
abstract final class CampaignPlayNavigation {
  static void _resetMatchTour(ProviderContainer container) {
    container.read(matchCoachTourProvider.notifier).reset();
  }

  static Future<void> _waitForPlayReady(
    ProviderContainer container,
    String levelId,
  ) async {
    if (container.read(campaignPlayReadyProvider) == levelId) return;

    final completer = Completer<void>();
    late final ProviderSubscription<String?> sub;
    sub = container.listen(campaignPlayReadyProvider, (prev, next) {
      if (next == levelId && !completer.isCompleted) {
        completer.complete();
      }
    }, fireImmediately: true);

    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Proceed — overlay pop still runs if navigation succeeded.
    } finally {
      sub.close();
    }
  }

  /// Pops the level-complete overlay, then replaces `/campaign/play/...` with
  /// the campaign tab so [GameScreen] is disposed before the map rebuilds.
  static void exitToMap(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    Future.microtask(() {
      CoachTourTargetRegistry.releaseAllGameTargets();
      _resetMatchTour(container);
      if (navigator.canPop()) {
        navigator.pop();
      }
      router.go(AppRoutes.campaign);
    });
  }

  /// Replaces the play route while the result overlay stays up, waits for the
  /// new level route to settle, then pops the overlay.
  ///
  /// [forceNewInstance] adds a `?r=` nonce so Try Again on the same level
  /// gets a fresh [GameScreen] (R9 regression guard).
  static Future<void> _exitToPlayLevel(
    BuildContext context, {
    required String levelId,
    bool forceNewInstance = false,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    final path = forceNewInstance
        ? '${AppRoutes.campaign}/play/$levelId?r=${DateTime.now().millisecondsSinceEpoch}'
        : '${AppRoutes.campaign}/play/$levelId';

    container.read(campaignPlayReadyProvider.notifier).state = null;
    CoachTourTargetRegistry.releaseAllGameTargets();
    _resetMatchTour(container);
    router.go(path);
    await _waitForPlayReady(container, levelId);

    if (rootNav.canPop()) {
      rootNav.pop();
    }
  }

  /// Pops overlays and replaces the play route to restart [levelId] from scratch.
  static Future<void> exitToReplayLevel(BuildContext context, String levelId) {
    return _exitToPlayLevel(context, levelId: levelId, forceNewInstance: true);
  }

  /// Replaces the current play route with the next level (avoids stacking routes).
  static Future<void> exitToNextLevel(BuildContext context, String levelId) {
    return _exitToPlayLevel(context, levelId: levelId);
  }
}
