import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/deep_links/challenge_link_parser.dart';
import '../backend/callable_backend.dart';

typedef ChallengeInviteHandler = void Function(String code);

/// Foreground delivery (Android tray is suppressed; show in-app UI instead).
typedef ForegroundChallengeInviteHandler = void Function(
  String code,
  String? notificationBody,
);

/// Firebase Cloud Messaging — token registration + challenge invite routing.
class FcmService {
  FcmService({CallableBackend? backend})
      : _backend = backend ?? CallableBackend.instance;

  final CallableBackend _backend;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  ChallengeInviteHandler? _onChallengeInvite;
  ForegroundChallengeInviteHandler? _onForegroundChallengeInvite;

  bool _initialized = false;

  bool get isAvailable => Firebase.apps.isNotEmpty;

  Future<void> initialize({
    ChallengeInviteHandler? onChallengeInvite,
    ForegroundChallengeInviteHandler? onForegroundChallengeInvite,
  }) async {
    if (!isAvailable || _initialized) return;
    _initialized = true;
    _onChallengeInvite = onChallengeInvite;
    _onForegroundChallengeInvite = onForegroundChallengeInvite;

    await _requestPermission();

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((_) {
      unawaited(registerToken());
    });

    _foregroundSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleMessage(initial);
    }
  }

  Future<void> registerToken() async {
    if (!isAvailable || !_backend.isAvailable) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _backend.call('registerFcmToken', {'token': token});
      if (kDebugMode) {
        debugPrint('[FCM] registerFcmToken succeeded');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FCM] registerFcmToken failed: $e\n$st');
      }
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _openedAppSub = null;
    _onChallengeInvite = null;
    _onForegroundChallengeInvite = null;
    _initialized = false;
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] permission request failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final code = ChallengeLinkParser.parseFcmData(message.data);
    if (code == null) return;

    if (kDebugMode) {
      debugPrint('[FCM] foreground challenge invite code=$code');
    }

    _onForegroundChallengeInvite?.call(
      code,
      message.notification?.body,
    );
  }

  void _handleMessage(RemoteMessage message) {
    final code = ChallengeLinkParser.parseFcmData(message.data);
    if (code == null) return;
    _onChallengeInvite?.call(code);
  }
}

/// Background isolate entry point (required by `firebase_messaging`).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] background message: ${message.messageId}');
  }
}
