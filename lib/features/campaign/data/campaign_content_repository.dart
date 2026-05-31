import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/campaign_level.dart';
import '../domain/campaign_world.dart';

/// Loads campaign level definitions from bundled JSON assets.
class CampaignContentRepository {
  CampaignContentRepository._();
  static final instance = CampaignContentRepository._();

  final _cache = <int, List<CampaignLevel>>{};

  Future<List<CampaignLevel>> levelsForWorld(int worldId) async {
    if (_cache.containsKey(worldId)) return _cache[worldId]!;
    final json = await rootBundle.loadString(
      'assets/campaign/world_$worldId.json',
    );
    final list = jsonDecode(json) as List<dynamic>;
    final levels = list
        .map((e) => CampaignLevel.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache[worldId] = levels;
    return levels;
  }

  Future<CampaignLevel?> levelById(String levelId) async {
    final parts = CampaignCatalog.parseLevelId(levelId);
    if (parts == null) return null;
    final (worldId, index) = parts;
    final levels = await levelsForWorld(worldId);
    return levels.firstWhere(
      (l) => l.index == index,
      orElse: () => levels.first,
    );
  }

  Future<List<CampaignLevel>> allLevels() async {
    final result = <CampaignLevel>[];
    for (final world in CampaignCatalog.worlds) {
      result.addAll(await levelsForWorld(world.id));
    }
    return result;
  }
}
