import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tutorial_catalog.dart';

const kTutorialSkippedKey = 'tutorial_skipped_v1';
const kTutorialLevelsDoneKey = 'tutorial_levels_done_v1';

class TutorialPreferences {
  const TutorialPreferences({
    required this.skipped,
    required this.completedLevelIds,
  });

  final bool skipped;
  final Set<String> completedLevelIds;

  bool shouldShowTutorial(String levelId) {
    if (!TutorialCatalog.isTutorialLevel(levelId)) return false;
    if (skipped) return false;
    return !completedLevelIds.contains(levelId);
  }

  bool get shouldShowTutorialOnHero =>
      !skipped && !completedLevelIds.contains('w1_l01');

  static Future<TutorialPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getBool(kTutorialSkippedKey) ?? false;
    final done = prefs.getStringList(kTutorialLevelsDoneKey) ?? const [];
    return TutorialPreferences(
      skipped: skipped,
      completedLevelIds: done.toSet(),
    );
  }

  static Future<void> markLevelComplete(String levelId) async {
    if (!TutorialCatalog.isTutorialLevel(levelId)) return;
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getStringList(kTutorialLevelsDoneKey) ?? [];
    if (done.contains(levelId)) return;
    await prefs.setStringList(kTutorialLevelsDoneKey, [...done, levelId]);
  }

  static Future<void> skipAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kTutorialSkippedKey, true);
    await prefs.setStringList(
      kTutorialLevelsDoneKey,
      TutorialCatalog.tutorialLevelIds,
    );
  }

  static Future<void> resetTutorialTips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kTutorialSkippedKey, false);
    await prefs.remove(kTutorialLevelsDoneKey);
  }
}
