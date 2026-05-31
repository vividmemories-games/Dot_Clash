import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase HTTPS callables (gen-2, `us-central1`).
///
/// Uses the official [HttpsCallable] client so Auth + App Check tokens are attached
/// by the native SDK. Do not POST to `cloudfunctions.net` directly — gen-1/2 IAM
/// returns HTML 401 for raw HTTP.
class CallableBackend {
  CallableBackend._();
  static final instance = CallableBackend._();

  static const _region = 'us-central1';

  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: _region,
      );

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (!isAvailable) {
      throw StateError('Firebase is not initialized.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in required for $name',
      );
    }

    // Force refresh so the native Functions SDK has a token to attach.
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Failed to refresh auth token for $name',
      );
    }

    final opts = Firebase.app().options;
    if (kDebugMode) {
      debugPrint(
        '[Callable] invoking $name '
        'project=${opts.projectId} '
        'authUid=${user.uid} '
        'idTokenAud=${_jwtClaim(idToken, 'aud')}',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      final result = await callable.call(data);
      if (kDebugMode) {
        debugPrint('[Callable] $name succeeded');
      }
      return _normalizeResult(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Callable] $name failed: code=${e.code} '
          'message=${e.message ?? '(none)'} '
          'details=${e.details}',
        );
        if (e.code == 'unauthenticated' && e.message == 'Sign in first.') {
          debugPrint(
            '[Callable] Function ran but request.auth was empty — '
            'redeploy gen-2 callables with invoker:public (see SETUP.md).',
          );
        }
      }
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeResult(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static String? _jwtClaim(String jwt, String claim) {
    final parts = jwt.split('.');
    if (parts.length < 2) return null;
    try {
      var payload = parts[1];
      final pad = payload.length % 4;
      if (pad > 0) payload += '=' * (4 - pad);
      final map = jsonDecode(utf8.decode(base64Url.decode(payload)));
      return map[claim]?.toString();
    } catch (_) {
      return null;
    }
  }
}
