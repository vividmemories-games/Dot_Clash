import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_router_refresh.dart';
import 'onboarding_router_refresh.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/campaign/data/campaign_content_repository.dart';
import '../../features/campaign/domain/campaign_level.dart';
import '../../features/campaign/domain/daily_puzzle.dart';
import '../../features/campaign/domain/turn_budget_calculator.dart';
import '../../features/campaign/presentation/campaign_map_screen.dart';
import '../../features/challenge/presentation/challenge_lobby_screen.dart';
import '../../features/challenge/presentation/challenge_play_screen.dart';
import '../../features/contact/presentation/contact_screen.dart';
import '../../features/game/domain/models/game_state.dart';
import '../../features/game/presentation/game_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/onboarding/presentation/onboarding_splash_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../services/ads/ad_service_provider.dart';
import '../../shared/widgets/app_shell.dart';

// ── Route names ───────────────────────────────────────────────────────────────
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String auth = '/';
  static const String home = '/home';
  static const String game = '/game';
  static const String shop = '/shop';
  static const String settings = '/settings';
  static const String contact = '/contact';
  static const String campaign = '/campaign';
  static const String campaignPlay = '/campaign/play/:levelId';
  static const String dailyPuzzle = '/daily-puzzle';
  static const String profile = '/profile';
  static const String challengeLobby = '/challenge/lobby/:code';
  static const String challengePlay = '/challenge/play/:code';

  static String challengeLobbyPath(String code) =>
      '/challenge/lobby/${code.trim().toUpperCase()}';

  static String challengePlayPath(String code) =>
      '/challenge/play/${code.trim().toUpperCase()}';
}

bool _isAuthRoute(GoRouterState state) {
  final loc = state.uri.path;
  if (loc.isEmpty || loc == '/') return true;
  final matched = state.matchedLocation;
  return matched == '/' || matched == AppRoutes.auth;
}

bool _isChallengeRoute(GoRouterState state) {
  return state.uri.path.startsWith('/challenge/');
}

// ── Provider ──────────────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  final firebaseConfigured = ref.watch(firebaseConfiguredProvider);
  final firebaseCoreReady = ref.watch(firebaseCoreReadyProvider);
  final authRefresh = ref.watch(authRouterRefreshProvider);
  final onboardingRefresh = ref.watch(onboardingRouterRefreshProvider);
  final rootNavigatorKey = ref.watch(rootNavigatorKeyProvider);

  // One-shot read for initial route only. Ongoing onboarding changes use
  // [onboardingRefresh] + redirect (must not watch here — invalidate + go()
  // leaves redirect with a stale ref).
  final onboardingSeen = ref.read(onboardingSeenProvider).valueOrNull;
  final initialLocation = onboardingSeen == false
      ? AppRoutes.splash
      : onboardingSeen == true
          ? (firebaseConfigured ? AppRoutes.auth : AppRoutes.home)
          : AppRoutes.splash;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    refreshListenable: Listenable.merge([authRefresh, onboardingRefresh]),
    redirect: (context, state) {
      // Read inside redirect so auth/onboarding refresh re-runs this without
      // recreating GoRouter (which would reset to [initialLocation]).
      final currentUser = ref.read(currentUserProvider);
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final onboardingComplete =
          ref.read(onboardingSeenProvider).valueOrNull ?? true;
      final isLoggedIn = currentUser != null;
      final isOnAuth = _isAuthRoute(state);

      String? redirectTarget;
      if (isSplash) {
        if (isLoggedIn)
          redirectTarget = AppRoutes.home;
        else if (onboardingComplete) redirectTarget = AppRoutes.auth;
      } else if (!onboardingComplete && !isLoggedIn) {
        redirectTarget = AppRoutes.splash;
      } else if (!firebaseConfigured) {
        redirectTarget = null;
      } else if (!firebaseCoreReady) {
        redirectTarget = null;
      } else if (!isLoggedIn && !isOnAuth) {
        if (_isChallengeRoute(state)) {
          redirectTarget =
              '${AppRoutes.auth}?next=${Uri.encodeComponent(state.uri.path)}';
        } else {
          redirectTarget = AppRoutes.auth;
        }
      } else if (isLoggedIn && isOnAuth) {
        final next = state.uri.queryParameters['next'];
        if (next != null &&
            next.startsWith('/challenge/') &&
            next.contains('/')) {
          redirectTarget = next;
        } else {
          redirectTarget = AppRoutes.home;
        }
      }

      return redirectTarget;
    },
    routes: [
      // ── Onboarding splash (first launch only) ───────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingSplashScreen()),
      ),

      // ── Full-screen routes (no bottom nav) ───────────────────────────────
      GoRoute(
        path: AppRoutes.auth,
        pageBuilder: (context, state) => _fadePage(state, const AuthScreen()),
      ),
      GoRoute(
        path: AppRoutes.game,
        pageBuilder: (context, state) {
          final config =
              state.extra as GameConfig? ?? GameConfig.defaultLocal();
          return _slidePage(state, GameScreen(config: config));
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) =>
            _slidePage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.contact,
        pageBuilder: (context, state) =>
            _slidePage(state, const ContactScreen()),
      ),
      GoRoute(
        path: AppRoutes.campaignPlay,
        pageBuilder: (context, state) {
          final levelId = state.pathParameters['levelId'] ?? 'w1_l01';
          return _campaignGamePage(state, levelId, isDaily: false);
        },
      ),
      GoRoute(
        path: AppRoutes.dailyPuzzle,
        pageBuilder: (context, state) => _dailyPuzzleGamePage(state),
      ),
      GoRoute(
        path: AppRoutes.challengeLobby,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _slidePage(
            state,
            ChallengeLobbyScreen(code: code),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.challengePlay,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return CustomTransitionPage<void>(
            key: ValueKey('challenge-play-$code'),
            child: ChallengePlayScreen(code: code),
            transitionDuration: const Duration(milliseconds: 280),
            transitionsBuilder: (_, animation, __, child) {
              final tween = Tween(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
          );
        },
      ),

      // ── Persistent tab shell ─────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    _fadePage(state, const HomeScreen()),
              ),
            ],
          ),
          // Tab 1: Campaign
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.campaign,
                pageBuilder: (context, state) =>
                    _fadePage(state, const CampaignMapScreen()),
              ),
            ],
          ),
          // Tab 2: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) =>
                    _fadePage(state, const ProfileScreen()),
              ),
            ],
          ),
          // Tab 3: Shop
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.shop,
                pageBuilder: (context, state) =>
                    _fadePage(state, const ShopScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _campaignGamePage(
  GoRouterState state,
  String levelId, {
  required bool isDaily,
}) {
  final replayNonce = state.uri.queryParameters['r'] ?? '';
  return CustomTransitionPage<void>(
    // go_router's default pageKey is the route pattern (`/campaign/play/:levelId`),
    // so level-to-level navigation must key by [levelId] (and replay nonce) or
    // [GameScreen] state sticks — see docs/RELEASES.md (Release 12).
    key: ValueKey(
      'campaign-play-$levelId$replayNonce${isDaily ? '-daily' : ''}',
    ),
    child: FutureBuilder<CampaignLevel?>(
      future: CampaignContentRepository.instance.levelById(levelId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final level = snap.data!;
        final turnBudget = TurnBudgetCalculator.budgetFor(level);
        final config = isDaily
            ? GameConfig.dailyPuzzle(
                levelId: level.id,
                gridSize: level.gridSize,
                difficulty: level.aiDifficulty,
                persona: level.parsedPersona,
                disabledCells: level.disabledCells,
              )
            : GameConfig.campaign(
                levelId: level.id,
                gridSize: level.gridSize,
                difficulty: level.aiDifficulty,
                persona: level.parsedPersona,
                disabledCells: level.disabledCells,
                turnBudget: turnBudget,
              );
        return GameScreen(key: ValueKey(level.id), config: config);
      },
    ),
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

CustomTransitionPage<void> _dailyPuzzleGamePage(GoRouterState state) {
  final levelId = DailyPuzzle.levelIdForToday();
  return _campaignGamePage(state, levelId, isDaily: true);
}

// ── Page transition helpers ────────────────────────────────────────────────────
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}
