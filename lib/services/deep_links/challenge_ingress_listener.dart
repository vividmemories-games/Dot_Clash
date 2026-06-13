import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deep_links/challenge_link_parser.dart';
import '../../core/router/app_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../services/ads/ad_service_provider.dart';
import '../../shared/feedback/app_snackbar.dart';
import '../push/fcm_providers.dart';

/// Listens for HTTPS/custom-scheme links and FCM challenge invites → lobby route.
class ChallengeIngressListener extends ConsumerStatefulWidget {
  const ChallengeIngressListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChallengeIngressListener> createState() =>
      _ChallengeIngressListenerState();
}

class _ChallengeIngressListenerState
    extends ConsumerState<ChallengeIngressListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _uriSub;
  String? _lastRoutedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!ref.read(firebaseCoreReadyProvider)) return;

    final fcm = ref.read(fcmServiceProvider);
    await fcm.initialize(
      onChallengeInvite: _openChallengeLobby,
      onForegroundChallengeInvite: _showForegroundChallengeInvite,
    );
    if (ref.read(currentUserProvider) != null) {
      unawaited(fcm.registerToken());
    }

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleUri(initialUri);
    }

    _uriSub = _appLinks.uriLinkStream.listen(_handleUri);
  }

  @override
  void dispose() {
    unawaited(_uriSub?.cancel());
    super.dispose();
  }

  void _handleUri(Uri uri) {
    final code = ChallengeLinkParser.parseChallengeCode(uri);
    if (code != null) _openChallengeLobby(code);
  }

  void _openChallengeLobby(String code) {
    if (!mounted) return;
    final normalized = ChallengeLinkParser.normalizeCode(code);
    if (normalized == null) return;

    // De-dupe rapid double delivery (initial link + stream, or FCM + link).
    if (_lastRoutedCode == normalized) return;
    _lastRoutedCode = normalized;

    ref.read(appRouterProvider).go(AppRoutes.challengeLobbyPath(normalized));
  }

  void _showForegroundChallengeInvite(String code, String? notificationBody) {
    final context = ref.read(rootNavigatorKeyProvider).currentContext;
    if (context == null || !context.mounted) return;

    final normalized = ChallengeLinkParser.normalizeCode(code);
    if (normalized == null) return;

    AppSnackBar.showWithAction(
      context,
      message: notificationBody ?? 'New challenge! Tap to join.',
      actionLabel: 'JOIN',
      onAction: () => _openChallengeLobby(normalized),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) {
      final wasLoggedIn = previous?.valueOrNull != null;
      final isLoggedIn = next.valueOrNull != null;
      if (!wasLoggedIn && isLoggedIn) {
        unawaited(ref.read(fcmServiceProvider).registerToken());
      }
    });

    return widget.child;
  }
}
