import 'package:dot_clash/features/profile/domain/lives_logic.dart';
import 'package:dot_clash/features/profile/domain/progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseNow = DateTime(2026, 1, 1, 12, 0, 0);

  group('LivesLogic.onLoss', () {
    test('full lives drops to 4 and starts timer', () {
      final next = LivesLogic.onLoss(
        lives: Progression.maxLives,
        nextLifeAt: null,
        now: baseNow,
      );

      expect(next.lives, Progression.maxLives - 1);
      expect(
        next.nextLifeAt,
        baseNow.add(Progression.lifeRegenDuration),
      );
    });
  });

  group('LivesLogic.resolve', () {
    test('regens one life after 20 minutes', () {
      final now = baseNow.add(const Duration(minutes: 20));
      final snapshot = LivesLogic.resolve(
        lives: 4,
        nextLifeAt: baseNow.add(const Duration(minutes: 20)),
        now: now,
      );

      expect(snapshot.effectiveLives, Progression.maxLives);
      expect(snapshot.nextLifeAt, isNull);
      expect(snapshot.timeUntilNextLife, isNull);
    });

    test('applies multiple regen ticks when app was backgrounded', () {
      final snapshot = LivesLogic.resolve(
        lives: 2,
        nextLifeAt: baseNow.add(const Duration(minutes: 20)),
        now: baseNow.add(const Duration(minutes: 65)),
      );

      expect(snapshot.effectiveLives, Progression.maxLives);
      expect(snapshot.nextLifeAt, isNull);
    });
  });

  group('LivesLogic.onPurchase', () {
    test('purchase at max lives stays capped', () {
      final next = LivesLogic.onPurchase(
        lives: Progression.maxLives,
        nextLifeAt: null,
        now: baseNow,
      );
      expect(next.lives, Progression.maxLives);
      expect(next.nextLifeAt, isNull);
    });

    test('purchase at zero lives restores one life and keeps timer', () {
      final next = LivesLogic.onPurchase(
        lives: 0,
        nextLifeAt: baseNow.add(const Duration(minutes: 10)),
        now: baseNow,
      );
      expect(next.lives, 1);
      expect(next.nextLifeAt, baseNow.add(const Duration(minutes: 10)));
    });
  });
}
