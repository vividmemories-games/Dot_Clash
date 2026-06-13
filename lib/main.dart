import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';
import 'core/env/app_env.dart';
import 'firebase_options.dart';
import 'services/analytics/analytics_service.dart';
import 'services/firebase/app_check_service.dart';
import 'services/push/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase (gracefully skips if not configured yet)
  await _initFirebase();

  runApp(const ProviderScope(child: DotClashApp()));
}

Future<void> _initFirebase() async {
  try {
    // Avoid hard-crashing on iOS/Android when firebase_options.dart is still the
    // placeholder template (TODO_* values) or when platform config files are missing.
    final opts = DefaultFirebaseOptions.currentPlatform;
    final looksUnconfigured =
        opts.apiKey.startsWith('TODO_') || opts.appId.startsWith('TODO_');
    if (looksUnconfigured) {
      debugPrint('[DotClash] Firebase not configured yet (skipping init).');
      return;
    }

    await Firebase.initializeApp(
      options: opts,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await AppCheckService.activate();
    await AppCheckService.warmUp();

    AnalyticsService.instance.init();
    final bootUid = FirebaseAuth.instance.currentUser?.uid;
    if (bootUid != null) {
      await AnalyticsService.instance.setUserId(bootUid);
    }

    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? AppEnv.googleSignInServerClientId : null,
        serverClientId: kIsWeb ? null : AppEnv.googleSignInServerClientId,
      );
    } catch (e, st) {
      debugPrint('[DotClash] Google Sign-In init failed: $e\n$st');
    }

    // Wire Crashlytics as Flutter error handler in release builds
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e, st) {
    // Keys may still look valid in firebase_options.dart — routing will show auth,
    // but sign-in stays disabled until this succeeds.
    debugPrint('[DotClash] Firebase not initialised: $e');
    debugPrint('$st');
  }

  if (kDebugMode) {
    try {
      final o = DefaultFirebaseOptions.currentPlatform;
      debugPrint(
        '[DotClash] bootstrap FLAVOR=${AppEnv.flavor} '
        'firebaseApps=${Firebase.apps.length} '
        'opts.apiKeyLen=${o.apiKey.length} '
        'opts.projectId=${o.projectId} '
        'opts.bundle=${o.iosBundleId ?? o.appId} '
        'opts.appId=${o.appId}',
      );
    } catch (e) {
      debugPrint('[DotClash] bootstrap firebase_options error: $e');
    }
  }
}
