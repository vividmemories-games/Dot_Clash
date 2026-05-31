// Dev Firebase project: dot-clash-dev
// Regenerate with:
//   flutterfire configure --project=dot-clash-dev --out=lib/firebase_options_dev.dart
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyANQ_WydnS5jotYemR8ePIPeI5OahAYTaI',
    appId: '1:218032510167:web:dca3f6c8f2236a0441cc92',
    messagingSenderId: '218032510167',
    projectId: 'dot-clash-dev',
    authDomain: 'dot-clash-dev.firebaseapp.com',
    storageBucket: 'dot-clash-dev.firebasestorage.app',
    measurementId: 'G-960SH7WQ9C',
  );

  /// Matches [android/app/src/dev/google-services.json] (`.dev` package client).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAsBiVxhMmf-vTsfqmHnNbzud-7W-kqs_E',
    appId: '1:218032510167:android:940568c54d577cc441cc92',
    messagingSenderId: '218032510167',
    projectId: 'dot-clash-dev',
    storageBucket: 'dot-clash-dev.firebasestorage.app',
  );

  /// Matches [ios/config/dev/GoogleService-Info.plist].
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBfB2S3QoeUq8pnmAInPkOR696wg50Nho8',
    appId: '1:218032510167:ios:fb46cd859a0b04fc41cc92',
    messagingSenderId: '218032510167',
    projectId: 'dot-clash-dev',
    storageBucket: 'dot-clash-dev.firebasestorage.app',
    iosBundleId: 'com.vividmemories.dotclash.dev',
  );

  /// No separate macOS app in dev; reuse iOS client options for desktop builds.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBfB2S3QoeUq8pnmAInPkOR696wg50Nho8',
    appId: '1:218032510167:ios:fb46cd859a0b04fc41cc92',
    messagingSenderId: '218032510167',
    projectId: 'dot-clash-dev',
    storageBucket: 'dot-clash-dev.firebasestorage.app',
    iosBundleId: 'com.vividmemories.dotclash.dev',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyANQ_WydnS5jotYemR8ePIPeI5OahAYTaI',
    appId: '1:218032510167:web:dca3f6c8f2236a0441cc92',
    messagingSenderId: '218032510167',
    projectId: 'dot-clash-dev',
    authDomain: 'dot-clash-dev.firebaseapp.com',
    storageBucket: 'dot-clash-dev.firebasestorage.app',
    measurementId: 'G-960SH7WQ9C',
  );
}
