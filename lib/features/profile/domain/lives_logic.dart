import 'progression.dart';

typedef LivesState = ({int lives, DateTime? nextLifeAt});

class LivesSnapshot {
  const LivesSnapshot({
    required this.effectiveLives,
    required this.nextLifeAt,
    required this.timeUntilNextLife,
  });

  final int effectiveLives;
  final DateTime? nextLifeAt;
  final Duration? timeUntilNextLife;

  bool get isFull => effectiveLives >= Progression.maxLives;
  bool get canPlayRanked => effectiveLives > 0;
}

abstract final class LivesLogic {
  static LivesSnapshot resolve({
    required int lives,
    required DateTime? nextLifeAt,
    required DateTime now,
  }) {
    var resolvedLives = lives.clamp(0, Progression.maxLives);
    DateTime? resolvedNextLifeAt = nextLifeAt;

    if (resolvedLives >= Progression.maxLives) {
      return const LivesSnapshot(
        effectiveLives: Progression.maxLives,
        nextLifeAt: null,
        timeUntilNextLife: null,
      );
    }

    if (resolvedNextLifeAt == null) {
      resolvedNextLifeAt = now.add(Progression.lifeRegenDuration);
    }

    while (resolvedLives < Progression.maxLives &&
        resolvedNextLifeAt != null &&
        !resolvedNextLifeAt.isAfter(now)) {
      resolvedLives++;
      if (resolvedLives < Progression.maxLives) {
        resolvedNextLifeAt =
            resolvedNextLifeAt.add(Progression.lifeRegenDuration);
      } else {
        resolvedNextLifeAt = null;
      }
    }

    final nextDuration = resolvedNextLifeAt == null
        ? null
        : resolvedNextLifeAt.difference(now).isNegative
            ? Duration.zero
            : resolvedNextLifeAt.difference(now);

    return LivesSnapshot(
      effectiveLives: resolvedLives,
      nextLifeAt: resolvedNextLifeAt,
      timeUntilNextLife: nextDuration,
    );
  }

  static LivesState onLoss({
    required int lives,
    required DateTime? nextLifeAt,
    required DateTime now,
  }) {
    final synced = resolve(lives: lives, nextLifeAt: nextLifeAt, now: now);
    var updatedLives = synced.effectiveLives;
    var updatedNextLifeAt = synced.nextLifeAt;

    if (updatedLives > 0) {
      updatedLives -= 1;
      if (updatedLives < Progression.maxLives && updatedNextLifeAt == null) {
        updatedNextLifeAt = now.add(Progression.lifeRegenDuration);
      }
    }

    return (lives: updatedLives, nextLifeAt: updatedNextLifeAt);
  }

  static LivesState onPurchase({
    required int lives,
    required DateTime? nextLifeAt,
    required DateTime now,
  }) {
    final synced = resolve(lives: lives, nextLifeAt: nextLifeAt, now: now);
    if (synced.effectiveLives >= Progression.maxLives) {
      return (lives: Progression.maxLives, nextLifeAt: null);
    }

    final updatedLives = synced.effectiveLives + 1;
    final updatedNextLifeAt = updatedLives >= Progression.maxLives
        ? null
        : (synced.nextLifeAt ?? now.add(Progression.lifeRegenDuration));

    return (lives: updatedLives, nextLifeAt: updatedNextLifeAt);
  }
}
