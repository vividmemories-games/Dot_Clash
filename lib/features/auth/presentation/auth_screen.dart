import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_error_message.dart';

import '../../../core/router/auth_router_refresh.dart';
import '../../../features/onboarding/providers/onboarding_provider.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/widgets/auth_provider_leading.dart';
import '../providers/auth_provider.dart';

enum _GuestProviderChoice { cancel, openSettings, useExistingAccount }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 36, end: 0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Auth actions (unchanged) ───────────────────────────────────────────────

  Future<void> _finishSignIn() async {
    await completeOnboarding(ref);
    // Re-run GoRouter redirect after sign-in settles. Do not use [BuildContext]
    // here — auth may already have navigated away and disposed this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authRouterRefreshProvider).refresh();
    });
  }

  Future<void> _signInAnonymously() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final configured = ref.read(firebaseConfiguredProvider);
      if (!configured) {
        if (mounted) context.go('/home');
        return;
      }

      final coreReady = ref.read(firebaseCoreReadyProvider);
      if (!coreReady) {
        if (mounted) context.go('/home');
        return;
      }

      await ref.read(authActionsProvider).signInAnonymously();
      await _finishSignIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAuthErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser?.isAnonymous ?? false) {
      final choice = await _showGuestProviderDialog(providerLabel: 'Google');
      if (!mounted || choice == _GuestProviderChoice.cancel) return;
      if (choice == _GuestProviderChoice.openSettings) {
        context.go('/settings');
        return;
      }
      await _signInToExistingProviderAccount(
        providerLabel: 'Google',
        signIn: () => ref.read(authActionsProvider).signInWithGoogle(),
      );
      return;
    }

    if (_loading) return;
    setState(() => _loading = true);

    try {
      final configured = ref.read(firebaseConfiguredProvider);
      if (!configured) {
        if (mounted) context.go('/home');
        return;
      }

      final user = await ref.read(authActionsProvider).signInWithGoogle();
      if (!mounted) return;
      if (user != null) await _finishSignIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAuthErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser?.isAnonymous ?? false) {
      final choice = await _showGuestProviderDialog(providerLabel: 'Apple');
      if (!mounted || choice == _GuestProviderChoice.cancel) return;
      if (choice == _GuestProviderChoice.openSettings) {
        context.go('/settings');
        return;
      }
      await _signInToExistingProviderAccount(
        providerLabel: 'Apple',
        signIn: () => ref.read(authActionsProvider).signInWithApple(),
      );
      return;
    }

    if (_loading) return;
    setState(() => _loading = true);

    try {
      final configured = ref.read(firebaseConfiguredProvider);
      if (!configured) {
        if (mounted) context.go('/home');
        return;
      }

      final user = await ref.read(authActionsProvider).signInWithApple();
      if (!mounted) return;
      if (user != null) await _finishSignIn();
    } catch (e) {
      if (!mounted) return;
      if (ref.read(currentUserProvider) != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatAuthErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInToExistingProviderAccount({
    required String providerLabel,
    required Future<User?> Function() signIn,
  }) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authActionsProvider).signOut();
      final user = await signIn();
      if (!mounted) return;
      if (user != null) await _finishSignIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAuthErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_GuestProviderChoice> _showGuestProviderDialog({
    required String providerLabel,
  }) async {
    final choice = await showDialog<_GuestProviderChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$providerLabel sign-in'),
          content: Text(
            'You are playing as a guest.\n\n'
            '• Save progress — link this guest profile to $providerLabel in Settings.\n'
            '• Use existing account — sign in to your saved $providerLabel profile '
            '(guest progress on this device will not carry over).',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_GuestProviderChoice.cancel),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(_GuestProviderChoice.useExistingAccount),
              child: Text('Use existing $providerLabel account'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_GuestProviderChoice.openSettings),
              child: const Text('Save guest progress'),
            ),
          ],
        );
      },
    );
    return choice ?? _GuestProviderChoice.cancel;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final configured = ref.watch(firebaseConfiguredProvider);
    final coreReady = ref.watch(firebaseCoreReadyProvider);
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Cinematic background ─────────────────────────────────────────
          Image.asset(
            'assets/images/auth_background.png',
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            errorBuilder: (_, __, ___) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [v.backgroundGradientTop, Colors.black],
                ),
              ),
            ),
          ),

          // ── Gradient scrim ───────────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.70),
                    Colors.black.withOpacity(0.96),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.38, 0.62, 1.0],
                ),
              ),
            ),
          ),

          // ── Animated content ─────────────────────────────────────────────
          SafeArea(
            child: AnimatedBuilder(
              animation: _enterCtrl,
              builder: (_, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
              ),
              child: Column(
                children: [
                  const Spacer(),

                  // ── Bottom action panel ────────────────────────────────
                  _AuthPanel(
                    loading: _loading,
                    configured: configured,
                    coreReady: coreReady,
                    isIos: isIos,
                    v: v,
                    onGuest: _signInAnonymously,
                    onGoogle: _signInWithGoogle,
                    onApple: _signInWithApple,
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

// ── Bottom action panel ───────────────────────────────────────────────────────

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.loading,
    required this.configured,
    required this.coreReady,
    required this.isIos,
    required this.v,
    required this.onGuest,
    required this.onGoogle,
    required this.onApple,
  });

  final bool loading;
  final bool configured;
  final bool coreReady;
  final bool isIos;
  final DotClashVisuals v;
  final VoidCallback onGuest;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xBF0A0A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Firebase error banner
          if (configured && !coreReady) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: v.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: v.red.withOpacity(0.4)),
              ),
              child: Text(
                'Firebase did not start — sign-in is unavailable.',
                style: TextStyle(
                  color: v.red.withOpacity(0.9),
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (configured) ...[
            // "LOGIN TO CONTINUE" header
            Row(
              children: [
                Expanded(
                    child: Divider(
                        color: Colors.white.withOpacity(0.15), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'LOGIN TO CONTINUE',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                Expanded(
                    child: Divider(
                        color: Colors.white.withOpacity(0.15), thickness: 1)),
              ],
            ),
            const SizedBox(height: 20),

            // Apple button (iOS only) — shown first
            if (isIos) ...[
              _AuthOutlineButton(
                onPressed: loading || !coreReady ? null : onApple,
                icon: loading
                    ? null
                    : Icon(
                        Icons.apple_rounded,
                        size: 22,
                        color: coreReady ? Colors.white : Colors.white24,
                      ),
                label: loading ? 'Connecting...' : 'CONTINUE WITH APPLE',
              ),
              const SizedBox(height: 12),
            ],

            // Google button (always shown when configured)
            _AuthOutlineButton(
              onPressed: loading || !coreReady ? null : onGoogle,
              icon: loading
                  ? null
                  : AuthProviderLeading.google(
                      enabled: coreReady,
                      disabledColor: Colors.white24,
                    ),
              label: loading ? 'Connecting...' : 'CONTINUE WITH GOOGLE',
            ),

            const SizedBox(height: 20),

            // OR divider
            Row(
              children: [
                Expanded(
                    child: Divider(
                        color: Colors.white.withOpacity(0.12), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                    child: Divider(
                        color: Colors.white.withOpacity(0.12), thickness: 1)),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Play as Guest
          GestureDetector(
            onTap: loading ? null : onGuest,
            child: Opacity(
              opacity: loading ? 0.45 : 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: const Color(0xFF64B5F6),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'PLAY AS GUEST',
                    style: TextStyle(
                      color: Color(0xFF64B5F6),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Trust badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: Color(0xFFCE93D8),
              ),
              SizedBox(width: 6),
              Text(
                'Your progress is safe and synced when you login.',
                style: TextStyle(
                  color: Color(0xFFCE93D8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Outlined auth button ──────────────────────────────────────────────────────

class _AuthOutlineButton extends StatelessWidget {
  const _AuthOutlineButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.06),
          side: BorderSide(
            color: Colors.white.withOpacity(enabled ? 0.22 : 0.08),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              SizedBox(width: 22, child: icon),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color:
                    enabled ? Colors.white.withOpacity(0.88) : Colors.white24,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
