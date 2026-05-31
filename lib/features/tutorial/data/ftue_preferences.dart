import 'package:shared_preferences/shared_preferences.dart';

import '../domain/coach_tour_catalog.dart';

const kHomeFtueCompleteKey = 'home_ftue_complete_v1';
const kHomeFtueSkippedKey = 'home_ftue_skipped_v1';
const kCampaignFtueCompleteKey = 'campaign_ftue_complete_v1';
const kCampaignFtueSkippedKey = 'campaign_ftue_skipped_v1';
const kCampaignFtueLevelsDoneKey = 'campaign_ftue_levels_done_v1';
const kFtueHoldGrantedKey = 'ftue_hold_granted_v1';

// Legacy keys (Phase 1 tutorial)
const kLegacyTutorialSkippedKey = 'tutorial_skipped_v1';
const kLegacyTutorialLevelsDoneKey = 'tutorial_levels_done_v1';

class FtuePreferences {
  const FtuePreferences({
    required this.homeTourComplete,
    required this.homeTourSkipped,
    required this.campaignFtueSkipped,
    required this.campaignLevelsDone,
    required this.holdGranted,
  });

  final bool homeTourComplete;
  final bool homeTourSkipped;
  final bool campaignFtueSkipped;
  final Set<String> campaignLevelsDone;
  final bool holdGranted;

  bool get shouldShowHomeTour => !homeTourComplete && !homeTourSkipped;

  bool get shouldShowTutorialOnHero =>
      !campaignFtueSkipped && !campaignLevelsDone.contains('w1_l01');

  bool shouldShowCampaignFtue(String levelId) {
    if (!CoachTourCatalog.isCampaignFtueLevel(levelId)) return false;
    if (campaignFtueSkipped || homeTourSkipped) return false;
    return !campaignLevelsDone.contains(levelId);
  }

  bool shouldFreeAttempt(String levelId) => shouldShowCampaignFtue(levelId);

  static Future<FtuePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();

    final legacySkipped = prefs.getBool(kLegacyTutorialSkippedKey) ?? false;
    final legacyDone =
        prefs.getStringList(kLegacyTutorialLevelsDoneKey) ?? const [];

    final homeComplete = prefs.getBool(kHomeFtueCompleteKey) ?? false;
    final homeSkipped =
        prefs.getBool(kHomeFtueSkippedKey) ?? legacySkipped;
    final campaignSkipped =
        prefs.getBool(kCampaignFtueSkippedKey) ?? legacySkipped;
    final campaignDone = {
      ...?prefs.getStringList(kCampaignFtueLevelsDoneKey),
      ...legacyDone,
    };
    final holdGranted = prefs.getBool(kFtueHoldGrantedKey) ?? false;

    return FtuePreferences(
      homeTourComplete: homeComplete,
      homeTourSkipped: homeSkipped,
      campaignFtueSkipped: campaignSkipped,
      campaignLevelsDone: campaignDone,
      holdGranted: holdGranted,
    );
  }

  static Future<void> markHomeTourComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHomeFtueCompleteKey, true);
  }

  static Future<void> markCampaignLevelComplete(String levelId) async {
    if (!CoachTourCatalog.isCampaignFtueLevel(levelId)) return;
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getStringList(kCampaignFtueLevelsDoneKey) ?? [];
    if (done.contains(levelId)) return;
    final updated = [...done, levelId];
    await prefs.setStringList(kCampaignFtueLevelsDoneKey, updated);

    if (CoachTourCatalog.campaignFtueLevelIds.every(updated.contains)) {
      await prefs.setBool(kCampaignFtueCompleteKey, true);
    }
  }

  static Future<void> skipHomeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHomeFtueSkippedKey, true);
    await prefs.setBool(kHomeFtueCompleteKey, true);
    await skipAllCampaignFtue(prefs);
  }

  static Future<void> skipAllCampaignFtue([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(kCampaignFtueSkippedKey, true);
    await prefs.setBool(kCampaignFtueCompleteKey, true);
    await prefs.setStringList(
      kCampaignFtueLevelsDoneKey,
      CoachTourCatalog.campaignFtueLevelIds,
    );
    await prefs.setBool(kLegacyTutorialSkippedKey, true);
    await prefs.setStringList(
      kLegacyTutorialLevelsDoneKey,
      CoachTourCatalog.campaignFtueLevelIds,
    );
  }

  static Future<void> markHoldGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kFtueHoldGrantedKey, true);
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kHomeFtueCompleteKey);
    await prefs.remove(kHomeFtueSkippedKey);
    await prefs.remove(kCampaignFtueCompleteKey);
    await prefs.remove(kCampaignFtueSkippedKey);
    await prefs.remove(kCampaignFtueLevelsDoneKey);
    // Keep ftue_hold_granted_v1 — one-time economy grant, not a tour flag.
    await prefs.remove(kLegacyTutorialSkippedKey);
    await prefs.remove(kLegacyTutorialLevelsDoneKey);
  }
}
