import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'campaign_world.dart';

/// Deterministic daily puzzle level selection (same level for all players per UTC day).
abstract final class DailyPuzzle {
  static const _salt = 'dot-clash-daily-v1';

  /// Picks a campaign level id from the full catalog using the UTC date seed.
  static String levelIdForDate(DateTime utcNow) {
    final day = _dateKey(utcNow.toUtc());
    final digest = sha1.convert(utf8.encode('$_salt-$day')).bytes;
    var worldIndex = digest[0] % CampaignCatalog.worlds.length;
    var world = CampaignCatalog.worlds[worldIndex];
    var levelIndex = (digest[1] % world.levelCount) + 1;
    return CampaignCatalog.levelId(world.id, levelIndex);
  }

  static String levelIdForToday() => levelIdForDate(DateTime.now().toUtc());

  static String _dateKey(DateTime utc) {
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }
}
