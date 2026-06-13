/// Consumable in-match boosts.
enum PowerUpType {
  hold,
  riposte,
  extraTurns,
  domino,
  flow,
}

extension PowerUpTypeX on PowerUpType {
  String get id => name;

  static PowerUpType? fromId(String id) {
    for (final t in PowerUpType.values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

class PowerUpInventory {
  const PowerUpInventory([this.counts = const {}]);

  final Map<String, int> counts;

  int countFor(PowerUpType type) => counts[type.id] ?? 0;

  PowerUpInventory withGrant(PowerUpType type, int qty) {
    final next = Map<String, int>.from(counts);
    next[type.id] = (next[type.id] ?? 0) + qty;
    return PowerUpInventory(next);
  }

  PowerUpInventory withConsume(PowerUpType type, {int qty = 1}) {
    final current = countFor(type);
    if (current < qty) return this;
    final next = Map<String, int>.from(counts);
    final left = current - qty;
    if (left <= 0) {
      next.remove(type.id);
    } else {
      next[type.id] = left;
    }
    return PowerUpInventory(next);
  }

  static PowerUpInventory fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const PowerUpInventory();
    return PowerUpInventory(
      Map<String, int>.from(
        raw.map((k, v) => MapEntry(k, (v as num).toInt())),
      ),
    );
  }

  Map<String, int> toMap() => Map<String, int>.from(counts);
}
