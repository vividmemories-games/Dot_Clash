import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../providers/auth_provider.dart';

/// User-facing auth failure text with provider error codes when available.
String formatAuthErrorMessage(Object error) {
  if (error is AuthAccountConflictException) {
    return error.message;
  }
  if (error is GoogleSignInException) {
    final code = error.code.name;
    final detail = error.description?.trim();
    if (detail != null && detail.isNotEmpty) {
      return '$detail (code $code)';
    }
    return 'Google sign-in failed (code $code)';
  }
  if (error is PlatformException) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return '$message (code ${error.code})';
    }
    return 'Sign-in failed (code ${error.code})';
  }
  if (error is FirebaseAuthException) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return '$message (code ${error.code})';
    }
    return 'Sign-in failed (code ${error.code})';
  }
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text;
}
