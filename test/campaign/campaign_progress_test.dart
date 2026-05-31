import 'package:dot_clash/features/campaign/domain/campaign_progress.dart';
import 'package:dot_clash/features/campaign/domain/campaign_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CampaignProgress.continueLevelId', () {
    test('returns first uncleared level', () {
      final progress = CampaignProgress(
        starsByLevelId: {
          'w1_l01': 3,
          'w1_l02': 3,
          'w1_l03': 1,
          'w1_l04': 3,
        },
      );
      expect(progress.continueLevelId, 'w1_l05');
    });

    test('does not replay level with 1–2 stars when next level is unlocked', () {
      final progress = CampaignProgress(
        starsByLevelId: {
          for (var i = 1; i <= 7; i++)
            CampaignCatalog.levelId(1, i): i == 7 ? 2 : 3,
        },
      );
      expect(progress.continueLevelId, 'w1_l08');
    });

    test('advances to next world when current world is fully cleared', () {
      final progress = CampaignProgress(
        starsByLevelId: {
          for (var i = 1; i <= CampaignCatalog.worldById(1).levelCount; i++)
            CampaignCatalog.levelId(1, i): 1,
        },
      );
      expect(progress.continueLevelId, 'w2_l01');
    });

    test('new player starts at world 1 level 1', () {
      const progress = CampaignProgress(starsByLevelId: {});
      expect(progress.continueLevelId, 'w1_l01');
    });
  });
}
