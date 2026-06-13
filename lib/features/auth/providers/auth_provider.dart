import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../firebase_options.dart';
import '../../settings/providers/settings_provider.dart';

/// True when `firebase_options.dart` has non-placeholder keys for this flavor.
///
/// Used for **navigation**: show the auth flow whenever the project is meant to
/// use Firebase, even if [Firebase.initializeApp] failed at runtime (otherwise iOS
/// would skip straight to home with no explanation).
final firebaseConfiguredProvider = Provider<bool>((ref) {
  try {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey.trim();
    return apiKey.isNotEmpty && !apiKey.startsWith('TODO_');
  } catch (_) {
    // Mis-generated options / unsupported platform in firebase_options_*.dart.
    return false;
  }
});

/// Default Firebase app exists after a successful [Firebase.initializeApp] call.
final firebaseCoreReadyProvider = Provider<bool>((ref) {
  return Firebase.apps.isNotEmpty;
});

/// Streams the current Firebase [User] (null = signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  final configured = ref.watch(firebaseConfiguredProvider);
  if (!configured) return const Stream.empty();

  if (Firebase.apps.isEmpty) {
    // Options look valid but Core never started (init exception, plist mismatch, etc.).
    // Emit signed-out once so redirects and UI don't sit in AsyncLoading forever.
    return Stream.value(null);
  }

  try {
    return _firebaseAuthStateStream();
  } catch (_) {
    return Stream.value(null);
  }
});

/// Emits persisted [FirebaseAuth.instance.currentUser] immediately, then listens
/// for changes. Avoids a loading window where [currentUserProvider] would fall
/// back to native currentUser and recreate profile streams twice on restart.
Stream<User?> _firebaseAuthStateStream() async* {
  yield FirebaseAuth.instance.currentUser;
  yield* FirebaseAuth.instance.authStateChanges();
}

/// Last signed-in user held during auth stream reload / keychain restore gaps.
final _authSessionUserProvider = StateProvider<User?>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirebaseAuth.instance.currentUser;
  }
  return null;
});

/// Keeps [_authSessionUserProvider] in sync without writing during provider build.
final _authSessionSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
    next.whenData((user) {
      if (ref.read(_authSessionUserProvider) != user) {
        ref.read(_authSessionUserProvider.notifier).state = user;
      }
    });
  });
});

/// Stable uid for profile loading — never flashes null while auth stream loads.
final profileUidProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.uid;
});

/// The current user, or null.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(_authSessionSyncProvider);
  final authState = ref.watch(authStateProvider);
  final session = ref.watch(_authSessionUserProvider);

  if (authState.hasValue) return authState.value;
  if (authState.isLoading) {
    final native =
        Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
    if (native != null) return native;
    // Keychain restore gap: keep last user so profile does not flash mock.
    return session;
  }
  final native =
      Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
  return native ?? session;
});

/// Actions: anonymous sign-in, Google sign-in, sign out.
final authActionsProvider = Provider<AuthActions>((ref) {
  return AuthActions(ref);
});

class AuthActions {
  const AuthActions(this._ref);

  final Ref _ref;

  Future<User?> signInAnonymously() async {
    final configured = _ref.read(firebaseConfiguredProvider);
    if (!configured) return null; // Offline mode
    if (!_ref.read(firebaseCoreReadyProvider)) {
      throw const _AuthException(_firebaseNotRunningMessage);
    }
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw _AuthException(e.message ?? 'Anonymous sign-in failed');
    }
  }

  /// Signs in with Google via Firebase Auth. Returns `null` if the user
  /// cancelled the Google UI.
  Future<User?> signInWithGoogle() async {
    final configured = _ref.read(firebaseConfiguredProvider);
    if (!configured) return null;
    if (!_ref.read(firebaseCoreReadyProvider)) {
      throw const _AuthException(_firebaseNotRunningMessage);
    }
    try {
      final googleSignInResult = await _googleSignInResult();
      if (googleSignInResult == null) return null;
      final cred = await FirebaseAuth.instance.signInWithCredential(
        googleSignInResult.credential,
      );
      final user = cred.user;
      await _syncNameToSettingsIfAvailable(
        user: user,
        googleUser: googleSignInResult.googleUser,
      );
      return user;
    } on FirebaseAuthException catch (e) {
      throw _AuthException(e.message ?? 'Google sign-in failed');
    }
  }

  Future<User?> signInWithApple() async {
    final configured = _ref.read(firebaseConfiguredProvider);
    if (!configured) return null;
    if (!_ref.read(firebaseCoreReadyProvider)) {
      throw const _AuthException(_firebaseNotRunningMessage);
    }

    final appleSignInResult = await _appleSignInResult();
    if (appleSignInResult == null) return null;

    try {
      final signedIn = await FirebaseAuth.instance.signInWithCredential(
        appleSignInResult.credential,
      );
      final user = signedIn.user;
      await _ensureFirebaseUserDisplayName(
        user: user,
        resolvedName: _resolveDisplayName(
          user: user,
          appleDisplayName: appleSignInResult.displayName,
        ),
      );
      await _syncNameToSettingsIfAvailable(
        user: user,
        appleDisplayName: appleSignInResult.displayName,
      );
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AppleAuth][signInWithApple] code=${e.code} message=${e.message}',
      );
      throw _AuthException(e.message ?? 'Apple sign-in failed');
    }
  }

  Future<User?> linkAnonymousWithGoogle() async {
    final configured = _ref.read(firebaseConfiguredProvider);
    if (!configured) return null;
    if (!_ref.read(firebaseCoreReadyProvider)) {
      throw const _AuthException(_firebaseNotRunningMessage);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const _AuthException(
        'Save Progress is only available while playing as a guest.',
      );
    }

    final googleSignInResult = await _googleSignInResult();
    if (googleSignInResult == null) return null;

    try {
      final linked =
          await user.linkWithCredential(googleSignInResult.credential);
      final linkedUser = linked.user;
      await _syncNameToSettingsIfAvailable(
        user: linkedUser,
        googleUser: googleSignInResult.googleUser,
      );
      return linkedUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') return user;
      if (_isCredentialAlreadyInUse(e)) {
        throw AuthAccountConflictException(
          _accountAlreadyInUseMessage,
          pendingCredential: e.credential,
        );
      }
      throw _AuthException(e.message ?? 'Failed to save progress with Google');
    }
  }

  Future<User?> linkAnonymousWithApple() async {
    final configured = _ref.read(firebaseConfiguredProvider);
    if (!configured) return null;
    if (!_ref.read(firebaseCoreReadyProvider)) {
      throw const _AuthException(_firebaseNotRunningMessage);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const _AuthException(
        'Save Progress is only available while playing as a guest.',
      );
    }

    final appleSignInResult = await _appleSignInResult();
    if (appleSignInResult == null) return null;

    try {
      final linked =
          await user.linkWithCredential(appleSignInResult.credential);
      final linkedUser = linked.user;
      await _ensureFirebaseUserDisplayName(
        user: linkedUser,
        resolvedName: _resolveDisplayName(
          user: linkedUser,
          appleDisplayName: appleSignInResult.displayName,
        ),
      );
      await _syncNameToSettingsIfAvailable(
        user: linkedUser,
        appleDisplayName: appleSignInResult.displayName,
      );
      return linkedUser;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AppleAuth][linkAnonymousWithApple] code=${e.code} message=${e.message}',
      );
      if (e.code == 'provider-already-linked') return user;
      if (_isCredentialAlreadyInUse(e)) {
        throw AuthAccountConflictException(
          _accountAlreadyInUseMessage,
          pendingCredential: e.credential,
        );
      }
      throw _AuthException(e.message ?? 'Failed to save progress with Apple');
    }
  }

  bool _isCredentialAlreadyInUse(FirebaseAuthException e) {
    if (e.code == 'credential-already-in-use' ||
        e.code == 'account-exists-with-different-credential' ||
        e.code == 'email-already-in-use') {
      return true;
    }
    final msg = e.message?.toLowerCase() ?? '';
    return msg.contains('already associated with a different user account') ||
        msg.contains('already in use');
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    if (Firebase.apps.isNotEmpty) {
      await FirebaseAuth.instance.signOut();
    }
    _ref.read(_authSessionUserProvider.notifier).state = null;
  }

  /// Re-authenticate before account deletion or other sensitive actions.
  Future<void> reauthenticateForSensitiveAction() async {
    if (!_ref.read(firebaseCoreReadyProvider)) {
      throw const _AuthException(_firebaseNotRunningMessage);
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const _AuthException('Not signed in.');
    }
    if (user.isAnonymous) return;

    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('google.com')) {
      final result = await _googleSignInResult();
      if (result == null) {
        throw const _AuthException('Google sign-in was canceled.');
      }
      await user.reauthenticateWithCredential(result.credential);
      return;
    }
    if (providers.contains('apple.com')) {
      final result = await _appleSignInResult();
      if (result == null) {
        throw const _AuthException('Apple sign-in was canceled.');
      }
      await user.reauthenticateWithCredential(result.credential);
      return;
    }
    throw const _AuthException(
      'Sign in again with your linked provider, then retry.',
    );
  }

  bool get isSignedIn =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  bool get isAnonymousGuest =>
      Firebase.apps.isNotEmpty &&
      (FirebaseAuth.instance.currentUser?.isAnonymous ?? false);

  String? get uid =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

  Future<User?> signInWithResolvedCredential(AuthCredential credential) async {
    final configured = _ref.read(firebaseConfiguredProvider);
    if (!configured) return null;
    if (!_ref.read(firebaseCoreReadyProvider)) {
      throw const _AuthException(_firebaseNotRunningMessage);
    }
    final cred = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = cred.user;
    await _syncNameToSettingsIfAvailable(user: user);
    return user;
  }

  Future<_GoogleSignInResult?> _googleSignInResult() async {
    try {
      GoogleSignInAccount? googleUser;
      final lightweight =
          GoogleSignIn.instance.attemptLightweightAuthentication();
      if (lightweight != null) {
        try {
          googleUser = await lightweight;
        } catch (_) {
          // Ignore lightweight failures and fall back to interactive auth.
        }
      }
      googleUser ??= await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final googleAuth = googleUser.authentication;
      return _GoogleSignInResult(
        credential: GoogleAuthProvider.credential(idToken: googleAuth.idToken),
        googleUser: googleUser,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw _AuthException(e.description ?? 'Google sign-in failed');
    }
  }

  Future<_AppleSignInResult?> _appleSignInResult() async {
    try {
      final rawNonce = _generateNonce();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256Of(rawNonce),
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const _AuthException('Apple sign-in did not return an ID token.');
      }

      final authCode = appleCredential.authorizationCode;
      final displayName = _fullNameFromAppleCredential(appleCredential);
      return _AppleSignInResult(
        credential: OAuthProvider('apple.com').credential(
          idToken: idToken,
          rawNonce: rawNonce,
          accessToken: authCode.isNotEmpty ? authCode : null,
        ),
        displayName: displayName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint(
        '[AppleAuth][_appleCredential] apple_code=${e.code.name} message=${e.message}',
      );
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw _AuthException('Apple sign-in failed: ${e.message}');
    } on SignInWithAppleNotSupportedException {
      debugPrint('[AppleAuth][_appleCredential] not_supported');
      throw const _AuthException(
        'Apple sign-in is not available on this device.',
      );
    } catch (e) {
      debugPrint('[AppleAuth][_appleCredential] unexpected=$e');
      rethrow;
    }
  }

  String? _fullNameFromAppleCredential(
      AuthorizationCredentialAppleID credential) {
    final givenName = credential.givenName?.trim() ?? '';
    final familyName = credential.familyName?.trim() ?? '';
    final fullName = [givenName, familyName]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
    return fullName.isEmpty ? null : fullName;
  }

  String? _resolveDisplayName({
    User? user,
    GoogleSignInAccount? googleUser,
    String? appleDisplayName,
  }) {
    final emailFallbackName = _displayNameFromEmail(user?.email);
    final options = [
      appleDisplayName,
      googleUser?.displayName,
      user?.displayName,
      emailFallbackName,
    ];
    for (final option in options) {
      final trimmed = option?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  Future<void> _ensureFirebaseUserDisplayName({
    required User? user,
    required String? resolvedName,
  }) async {
    if (user == null || resolvedName == null) return;
    if ((user.displayName ?? '').trim().isNotEmpty) return;
    await user.updateDisplayName(resolvedName);
    await user.reload();
  }

  Future<void> _syncNameToSettingsIfAvailable({
    required User? user,
    GoogleSignInAccount? googleUser,
    String? appleDisplayName,
  }) async {
    final resolvedName = _resolveDisplayName(
      user: user,
      googleUser: googleUser,
      appleDisplayName: appleDisplayName,
    );
    if (resolvedName == null) return;
    await _ref
        .read(settingsProvider.notifier)
        .applyAccountDisplayNameIfDefaults(resolvedName);
    await _syncNameToProfileIfDefault(
      uid: user?.uid,
      resolvedName: resolvedName,
    );
  }

  Future<void> _syncNameToProfileIfDefault({
    required String? uid,
    required String resolvedName,
  }) async {
    final trimmed = resolvedName.trim();
    if (uid == null || trimmed.isEmpty) return;
    try {
      final doc = FirebaseFirestore.instance.collection('profiles').doc(uid);
      final snap = await doc.get();
      final existingName =
          (snap.data()?['displayName'] as String?)?.trim() ?? '';
      final shouldApplyDefaultName =
          existingName.isEmpty || existingName == 'Player';
      if (!shouldApplyDefaultName) return;
      await doc.set({
        'displayName': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Keep auth flow resilient if Firestore is temporarily unavailable.
    }
  }

  String? _displayNameFromEmail(String? email) {
    final trimmed = email?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 0) return null;
    final localPart = trimmed.substring(0, atIndex).trim();
    if (localPart.isEmpty) return null;
    final words = localPart
        .split(RegExp(r'[._-]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    final normalized = words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ')
        .trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _sha256Of(String value) {
    final bytes = utf8.encode(value);
    return sha256.convert(bytes).toString();
  }
}

const String _firebaseNotRunningMessage =
    'Firebase did not start on this device. On iOS, confirm the dev flavor '
    'copied GoogleService-Info.plist (bundle ID com.vividmemories.dotclash.dev) '
    'and check the console for "[DotClash] Firebase".';

const String _accountAlreadyInUseMessage =
    'This account is already linked to another Dot Clash profile. '
    'Sign out and continue with that account to use it.';

class AuthAccountConflictException implements Exception {
  const AuthAccountConflictException(
    this.message, {
    this.pendingCredential,
  });

  final String message;
  final AuthCredential? pendingCredential;

  @override
  String toString() => message;
}

class _AuthException implements Exception {
  const _AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _GoogleSignInResult {
  const _GoogleSignInResult({
    required this.credential,
    required this.googleUser,
  });

  final AuthCredential credential;
  final GoogleSignInAccount googleUser;
}

class _AppleSignInResult {
  const _AppleSignInResult({
    required this.credential,
    required this.displayName,
  });

  final AuthCredential credential;
  final String? displayName;
}
