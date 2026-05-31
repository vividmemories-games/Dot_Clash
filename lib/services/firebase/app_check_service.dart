import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/env/app_env.dart';

/// Initializes Firebase App Check with flavor-appropriate attestation providers.
///
/// - **dev** / debug builds: debug providers (register the printed token in Firebase Console).
/// - **prod** release: Play Integrity (Android) and App Attest + Device Check fallback (iOS).
abstract final class AppCheckService {
  static bool _activated = false;

  static bool get isActivated => _activated;

  /// Production attestation (store / TestFlight release with `--flavor prod`).
  static bool get _useProductionProviders => AppEnv.isProd && kReleaseMode;

  static String get _firebaseProjectId =>
      AppEnv.isProd ? 'dot-clash-72cc6' : 'dot-clash-dev';

  /// Call once after [Firebase.initializeApp].
  static Future<void> activate() async {
    if (_activated || Firebase.apps.isEmpty) return;

    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint('[AppCheck] Web: App Check not configured (mobile-only app).');
      }
      return;
    }

    final AndroidAppCheckProvider providerAndroid;
    final AppleAppCheckProvider providerApple;
    if (_useProductionProviders) {
      providerAndroid = const AndroidPlayIntegrityProvider();
      providerApple = const AppleAppAttestWithDeviceCheckFallbackProvider();
    } else {
      final debugToken = AppEnv.appCheckDebugToken.isEmpty
          ? null
          : AppEnv.appCheckDebugToken;
      providerAndroid = AndroidDebugProvider(debugToken: debugToken);
      providerApple = AppleDebugProvider(debugToken: debugToken);
    }

    final appCheck = FirebaseAppCheck.instanceFor(app: Firebase.app());
    await appCheck.activate(
      // Explicit legacy enums so native never falls back to Device Check on simulator.
      // ignore: deprecated_member_use
      androidProvider: _useProductionProviders
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      // ignore: deprecated_member_use
      appleProvider: _useProductionProviders
          ? AppleProvider.appAttestWithDeviceCheckFallback
          : AppleProvider.debug,
      providerAndroid: providerAndroid,
      providerApple: providerApple,
    );

    await appCheck.setTokenAutoRefreshEnabled(true);
    _activated = true;

    if (kDebugMode) {
      debugPrint(
        '[AppCheck] activated '
        'flavor=${AppEnv.flavor} '
        'release=$kReleaseMode '
        'android=${providerAndroid.type} '
        'apple=${providerApple.type}',
      );
      if (!_useProductionProviders) {
        _printDebugSetupHint();
      }
    }
  }

  /// Forces a token fetch so misconfiguration surfaces early in debug builds.
  static Future<void> warmUp() async {
    if (!_activated || kIsWeb) return;
    try {
      final token =
          await FirebaseAppCheck.instanceFor(app: Firebase.app()).getToken(true);
      if (kDebugMode && token != null && token.isNotEmpty) {
        debugPrint('[AppCheck] token warm-up OK');
      }
    } catch (e, st) {
      if (kDebugMode) {
        final message = e.toString();
        if (message.contains('DeviceCheckProvider')) {
          debugPrint(
            '[AppCheck] Simulator cannot use Device Check. '
            'Pass --dart-define=APP_CHECK_DEBUG_TOKEN=... (register in Firebase Console) '
            'and do a full restart after changing native iOS build scripts.',
          );
        } else if (message.contains('403') || message.contains('PERMISSION_DENIED')) {
          _printDebugSetupHint(is403: true);
        } else {
          debugPrint('[AppCheck] token warm-up failed: $e');
        }
        debugPrint('$st');
      }
    }
  }

  static void _printDebugSetupHint({bool is403 = false}) {
    final project = _firebaseProjectId;
    final consoleUrl =
        'https://console.firebase.google.com/project/$project/appcheck/apps';

    debugPrint(
      is403
          ? '[AppCheck] 403 on exchangeDebugToken — Firebase rejected the simulator debug token.'
          : '[AppCheck] Dev simulator needs a registered App Check debug token.',
    );
    debugPrint('[AppCheck] Console: $consoleUrl');
    debugPrint(
      '[AppCheck] 1) Open the iOS app (bundle com.vividmemories.dotclash.dev) '
      '→ Register → choose **Debug** provider if not already registered.',
    );
    debugPrint(
      '[AppCheck] 2) **Manage debug tokens** → Add token. '
      'Find it in Xcode device logs (search "Firebase App Check Debug Token") '
      'or use a fixed UUID (see SETUP.md §2f).',
    );
    if (AppEnv.appCheckDebugToken.isNotEmpty) {
      debugPrint(
        '[AppCheck] You passed APP_CHECK_DEBUG_TOKEN — register that exact value in the console, '
        'then fully restart the app (not hot reload).',
      );
    } else {
      debugPrint(
        '[AppCheck] Tip: run `uuidgen`, register it in the console, then:\n'
        '  flutter run --flavor dev --dart-define=FLAVOR=dev '
        '--dart-define=APP_CHECK_DEBUG_TOKEN=<uuid>',
      );
    }
  }
}
