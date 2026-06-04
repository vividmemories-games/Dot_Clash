import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../tutorial/presentation/coach_tour_target.dart';
import '../../tutorial/providers/coach_tour_provider.dart';

/// Exits an in-progress campaign level (and any modal above it) back to the map.
abstract final class CampaignPlayNavigation {
  static void _resetMatchTour(ProviderContainer container) {
    container.read(matchCoachTourProvider.notifier).reset();
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

  /// Pops overlays and replaces the play route to restart [levelId] from scratch.
  static void exitToReplayLevel(BuildContext context, String levelId) {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final path = '${AppRoutes.campaign}/play/$levelId';
    Future.microtask(() {
      CoachTourTargetRegistry.releaseAllGameTargets();
      _resetMatchTour(container);
      if (navigator.canPop()) {
        navigator.pop();
      }
      router.go(path);
    });
  }

  /// Pops the complete overlay, then replaces the current play route with the
  /// next level (avoids stacking two play routes).
  static void exitToNextLevel(BuildContext context, String levelId) {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final path = '${AppRoutes.campaign}/play/$levelId';
    Future.microtask(() {
      CoachTourTargetRegistry.releaseAllGameTargets();
      _resetMatchTour(container);
      if (navigator.canPop()) {
        navigator.pop();
      }
      router.go(path);
    });
  }
}
