// ignore_for_file: avoid_print
/// Validates bundled campaign JSON (schema, counts, boss cadence).
///
/// Run: dart run tool/validate_levels.dart
import 'dart:convert';
import 'dart:io';

const worldCounts = {1: 10, 2: 20, 3: 25, 4: 25, 5: 20};
const bossLevels = {
  1: [5, 10],
  2: [10, 20],
  3: [10, 20, 25],
  4: [10, 20, 25],
  5: [10, 20],
};

void main() {
  var errors = 0;
  var total = 0;
  var bosses = 0;

  for (final entry in worldCounts.entries) {
    final worldId = entry.key;
    final expected = entry.value;
    final path = 'assets/campaign/world_$worldId.json';
    final file = File(path);
    if (!file.existsSync()) {
      print('ERROR: missing $path');
      errors++;
      continue;
    }
    final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    if (list.length != expected) {
      print('ERROR: $path has ${list.length} levels, expected $expected');
      errors++;
    }
    total += list.length;

    for (final raw in list) {
      final m = raw as Map<String, dynamic>;
      final id = m['id'] as String?;
      final index = m['index'] as int?;
      final isBoss = m['isBoss'] as bool? ?? false;
      if (id == null || index == null) {
        print('ERROR: $path level missing id/index');
        errors++;
        continue;
      }
      if (isBoss) {
        bosses++;
        if (m['aiDifficulty'] != 'hard') {
          print('ERROR: boss $id must use hard difficulty');
          errors++;
        }
      }
      final expectedBosses = bossLevels[worldId] ?? [];
      if (isBoss != expectedBosses.contains(index)) {
        print('ERROR: $id boss flag mismatch (index $index)');
        errors++;
      }
      final grid = m['gridSize'] as int?;
      if (grid == null || grid < 4 || grid > 8) {
        print('ERROR: $id invalid gridSize $grid');
        errors++;
      }
    }
  }

  if (total != 100) {
    print('ERROR: total levels $total, expected 100');
    errors++;
  }
  if (bosses != 12) {
    print('ERROR: total bosses $bosses, expected 12');
    errors++;
  }

  if (errors == 0) {
    print('OK: $total levels, $bosses bosses validated.');
  } else {
    print('FAILED: $errors error(s)');
    exit(1);
  }
}
