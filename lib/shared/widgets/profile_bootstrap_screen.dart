import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/theme/dot_clash_visuals.dart';
import '../../features/home/presentation/widgets/home_screen_background.dart';
import '../../features/profile/providers/profile_bootstrap_provider.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../layout/app_spacing.dart';

/// Branded full-screen gate shown while the first profile snapshot loads.
class ProfileBootstrapScreen extends StatelessWidget {
  const ProfileBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: v.scaffold,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash_onboarding.png',
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            errorBuilder: (_, __, ___) => ColoredBox(color: v.scaffold),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.72),
                  v.scaffold.withValues(alpha: 0.96),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DOT CLASH',
                      style: t.heroTitle.copyWith(
                        fontSize: 34,
                        letterSpacing: 5,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: v.playerA.withValues(alpha: 0.75),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapSM,
                    Text(
                      'Loading your progress…',
                      style: t.bodySmall.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapLG,
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: v.playerA,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the first profile fetch fails (rare — offline / permission).
class ProfileBootstrapErrorScreen extends ConsumerWidget {
  const ProfileBootstrapErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final message = ref.watch(profileProvider).error?.toString();

    return Scaffold(
      backgroundColor: v.scaffold,
      body: HomeScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: v.textSecondary),
                AppSpacing.vGapMD,
                Text(
                  'Couldn\'t load profile',
                  style: t.playerName.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.vGapSM,
                Text(
                  'Check your connection and try again.',
                  style: t.bodySmall.copyWith(color: v.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (message != null && message.isNotEmpty) ...[
                  AppSpacing.vGapSM,
                  Text(
                    message,
                    style: t.bodySmall.copyWith(
                      color: v.textDisabled,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                AppSpacing.vGapLG,
                FilledButton(
                  onPressed: () => ref.invalidate(profileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback guard for tab screens if they mount before bootstrap completes.
class ProfileReadyGate extends ConsumerWidget {
  const ProfileReadyGate({
    super.key,
    required this.child,
    this.loading,
  });

  final Widget child;
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(profileBootstrapProvider);
    if (bootstrap == ProfileBootstrapState.ready) return child;
    return loading ?? const ProfileTabLoadingPlaceholder();
  }
}

/// Lightweight in-tab placeholder (defense in depth behind [AppShell] gate).
class ProfileTabLoadingPlaceholder extends StatelessWidget {
  const ProfileTabLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.dc;

    return Scaffold(
      backgroundColor: v.scaffold,
      body: HomeScreenBackground(
        child: const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
