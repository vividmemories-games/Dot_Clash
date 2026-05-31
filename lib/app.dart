import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dot_clash_visuals.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/profile/providers/profile_providers.dart';
import 'services/ads/ad_service_provider.dart';
import 'services/analytics/analytics_service.dart';

class DotClashApp extends ConsumerStatefulWidget {
  const DotClashApp({super.key});

  @override
  ConsumerState<DotClashApp> createState() => _DotClashAppState();
}

class _DotClashAppState extends ConsumerState<DotClashApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adServiceProvider).init();
      final initial = ref.read(currentUserProvider);
      final initialUid = initial?.uid;
      if (initialUid != null && initialUid.isNotEmpty) {
        AnalyticsService.instance.setUserId(initialUid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.whenData((user) {
        final uid = user?.uid;
        AnalyticsService.instance.setUserId(
          uid != null && uid.isNotEmpty ? uid : null,
        );
      });
    });

    final router = ref.watch(appRouterProvider);
    final equippedThemeId =
        ref.watch(profileProvider.select((value) => value.valueOrNull?.themeId));
    final visuals = DotClashVisuals.fromThemeId(equippedThemeId);

    return MaterialApp.router(
      title: 'Dot Clash',
      theme: AppTheme.fromVisuals(visuals),
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
