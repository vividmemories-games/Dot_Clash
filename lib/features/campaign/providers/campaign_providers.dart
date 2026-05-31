import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_providers.dart';
import '../data/campaign_content_repository.dart';
import '../domain/campaign_level.dart';
import '../domain/campaign_progress.dart';
import '../domain/campaign_world.dart';

// ── Content repo ──────────────────────────────────────────────────────────────

final campaignContentRepoProvider = Provider<CampaignContentRepository>(
  (_) => CampaignContentRepository.instance,
);

// ── Progress derived from profile ─────────────────────────────────────────────

final campaignProgressProvider = Provider<CampaignProgress>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  return CampaignProgress(
    starsByLevelId: profile?.campaignStars ?? const {},
    lastLevelId: profile?.lastCampaignLevelId,
  );
});

// ── World levels ──────────────────────────────────────────────────────────────

final worldLevelsProvider =
    FutureProvider.family<List<CampaignLevel>, int>((ref, worldId) async {
  final repo = ref.watch(campaignContentRepoProvider);
  return repo.levelsForWorld(worldId);
});

// ── Single level ──────────────────────────────────────────────────────────────

final campaignLevelProvider =
    FutureProvider.family<CampaignLevel?, String>((ref, levelId) async {
  final repo = ref.watch(campaignContentRepoProvider);
  return repo.levelById(levelId);
});

// ── Continue level ID ─────────────────────────────────────────────────────────

final continueLevelIdProvider = Provider<String?>((ref) {
  final progress = ref.watch(campaignProgressProvider);
  return progress.continueLevelId;
});

// ── Continue level ────────────────────────────────────────────────────────────

final continueLevelProvider = FutureProvider<CampaignLevel?>((ref) async {
  final id = ref.watch(continueLevelIdProvider);
  if (id == null) return null;
  final repo = ref.watch(campaignContentRepoProvider);
  return repo.levelById(id);
});
