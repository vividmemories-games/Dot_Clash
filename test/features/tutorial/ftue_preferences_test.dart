import 'package:dot_clash/features/tutorial/data/ftue_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FtuePreferences', () {
    test('home tour skip blocks campaign FTUE', () {
      const prefs = FtuePreferences(
        homeTourComplete: true,
        homeTourSkipped: true,
        campaignFtueSkipped: true,
        campaignLevelsDone: {},
        holdGranted: false,
      );
      expect(prefs.shouldShowHomeTour, isFalse);
      expect(prefs.shouldShowCampaignFtue('w1_l01'), isFalse);
      expect(prefs.shouldFreeAttempt('w1_l01'), isFalse);
    });

    test('pending w1_l01 shows hero tutorial copy', () {
      const prefs = FtuePreferences(
        homeTourComplete: true,
        homeTourSkipped: false,
        campaignFtueSkipped: false,
        campaignLevelsDone: {},
        holdGranted: false,
      );
      expect(prefs.shouldShowTutorialOnHero, isTrue);
    });

    test('completed levels hide per-level FTUE', () {
      const prefs = FtuePreferences(
        homeTourComplete: true,
        homeTourSkipped: false,
        campaignFtueSkipped: false,
        campaignLevelsDone: {'w1_l01', 'w1_l02'},
        holdGranted: true,
      );
      expect(prefs.shouldShowCampaignFtue('w1_l01'), isFalse);
      expect(prefs.shouldShowCampaignFtue('w1_l03'), isTrue);
      expect(prefs.shouldShowCampaignFtue('w1_l05'), isFalse);
    });

    test('holdGranted blocks repeat FTUE hold grant', () {
      const prefs = FtuePreferences(
        homeTourComplete: false,
        homeTourSkipped: false,
        campaignFtueSkipped: false,
        campaignLevelsDone: {},
        holdGranted: true,
      );
      expect(prefs.holdGranted, isTrue);
    });
  });
}
