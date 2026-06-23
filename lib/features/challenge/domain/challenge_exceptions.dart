import 'package:cloud_functions/cloud_functions.dart';

/// Maps callable failures to player-facing copy for challenge flows.
class ChallengeException implements Exception {
  const ChallengeException(this.message);

  final String message;

  @override
  String toString() => message;

  static ChallengeException fromFirebase(FirebaseFunctionsException e) {
    final code = e.code;
    final msg = e.message ?? '';

    if (code == 'unauthenticated') {
      return const ChallengeException('Sign in to challenge a friend.');
    }
    if (code == 'not-found') {
      if (msg.contains('Profile')) {
        return const ChallengeException(
          'Your profile is still loading. Try again in a moment.',
        );
      }
      return const ChallengeException('Challenge not found. Check the code.');
    }
    if (code == 'invalid-argument') {
      if (msg.contains('own challenge')) {
        return const ChallengeException('You cannot join your own challenge.');
      }
      return ChallengeException(msg.isEmpty ? 'Invalid challenge code.' : msg);
    }
    if (code == 'failed-precondition') {
      if (msg.contains('full')) {
        return const ChallengeException('This challenge is already full.');
      }
      if (msg.contains('expired')) {
        return const ChallengeException('This challenge expired.');
      }
      if (msg.contains('joinable')) {
        return const ChallengeException(
            'This challenge is no longer joinable.');
      }
      return ChallengeException(msg.isEmpty ? 'Challenge unavailable.' : msg);
    }
    if (code == 'permission-denied') {
      return const ChallengeException('You are not in this challenge.');
    }

    return ChallengeException(msg.isEmpty ? 'Something went wrong.' : msg);
  }
}
