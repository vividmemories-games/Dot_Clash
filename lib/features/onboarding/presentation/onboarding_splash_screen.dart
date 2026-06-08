import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/onboarding/providers/onboarding_provider.dart';
import '../../../services/analytics/analytics_service.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/layout/app_spacing.dart';

class OnboardingSplashScreen extends ConsumerStatefulWidget {
  const OnboardingSplashScreen({super.key});

  @override
  ConsumerState<OnboardingSplashScreen> createState() =>
      _OnboardingSplashScreenState();
}

class _OnboardingSplashScreenState extends ConsumerState<OnboardingSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  late final Animation<double> _slideUp;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeIn);
    _slideUp = Tween<double>(begin: 32, end: 0).animate(
      CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Future<void> _onPlay() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      await completeOnboarding(ref);
      await AnalyticsService.instance.logOnboardingComplete();
      // Navigation: GoRouter redirect (via OnboardingRouterRefresh), not go().
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen cinematic background ─────────────────────────────
          Image.asset(
            'assets/images/splash_onboarding.png',
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),

          // ── Bottom gradient overlay ───────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.92),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // ── Animated content ─────────────────────────────────────────────
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: 64,
            child: AnimatedBuilder(
              animation: _fade,
              builder: (_, child) => Opacity(
                opacity: _opacity.value,
                child: Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App name
                  Text(
                    'DOT CLASH',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 6,
                      shadows: [
                        Shadow(
                          color: v.playerA.withOpacity(0.8),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'REMEMBER THIS GAME FROM CLASS?',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60,
                          letterSpacing: 2,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: v.playerA,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.roundedLG,
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      onPressed: _navigating ? null : _onPlay,
                      child: Text(
                        "LET'S PLAY",
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: Colors.black,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _navigating ? null : _onPlay,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
