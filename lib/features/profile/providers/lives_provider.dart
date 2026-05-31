import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/lives_logic.dart';
import '../domain/progression.dart';
import '../domain/user_profile.dart';
import 'profile_providers.dart';

class LivesController {
  const LivesController(this._repo);

  final ProfileRepository _repo;

  Future<void> syncLives() => _repo.syncLives();

  Future<bool> purchaseLife() => _repo.purchaseLife();
}

final livesControllerProvider = Provider<LivesController>((ref) {
  return LivesController(ref.watch(profileRepositoryProvider));
});

final _livesTickerProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

final _livesSyncKickProvider = Provider.autoDispose<void>((ref) {
  Timer? debounce;
  ref.onDispose(() => debounce?.cancel());

  ref.listen<AsyncValue<UserProfile>>(profileProvider, (previous, next) {
    final prevProfile = previous?.valueOrNull;
    final nextProfile = next.valueOrNull;
    if (nextProfile == null) return;
    if (prevProfile?.lives == nextProfile.lives &&
        prevProfile?.nextLifeAt == nextProfile.nextLifeAt) {
      return;
    }
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(ref.read(profileRepositoryProvider).syncLives());
    });
  });
});

final livesSnapshotProvider = Provider<LivesSnapshot>((ref) {
  ref.watch(_livesSyncKickProvider);
  final profile = ref.watch(profileProvider).valueOrNull;
  final now = ref.watch(_livesTickerProvider).valueOrNull ?? DateTime.now();
  if (profile == null) {
    return LivesLogic.resolve(
      lives: Progression.maxLives,
      nextLifeAt: null,
      now: now,
    );
  }
  return LivesLogic.resolve(
    lives: profile.lives,
    nextLifeAt: profile.nextLifeAt,
    now: now,
  );
});
