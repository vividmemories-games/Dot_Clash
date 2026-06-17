import 'package:dot_clash/features/challenge/domain/challenge_board_preset.dart';
import 'package:dot_clash/features/challenge/domain/create_challenge_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChallengeBoardPreset', () {
    test('all contains Classic, Blitz, Fortress in sort order', () {
      expect(ChallengeBoardPreset.all.length, 3);
      expect(ChallengeBoardPreset.all.map((p) => p.id), [
        'challenge_classic',
        'challenge_blitz',
        'challenge_fortress',
      ]);
    });

    test('byId resolves known presets', () {
      expect(
        ChallengeBoardPreset.byId('challenge_fortress')?.rows,
        5,
      );
      expect(ChallengeBoardPreset.byId('invalid'), isNull);
    });
  });

  group('CreateChallengeResult', () {
    test('fromCallable parses extended response', () {
      final result = CreateChallengeResult.fromCallable({
        'success': true,
        'code': 'abc123',
        'boardPresetId': 'challenge_blitz',
        'boardPresetName': 'Blitz',
        'rows': 4,
        'cols': 4,
      });

      expect(result.code, 'ABC123');
      expect(result.boardPresetId, 'challenge_blitz');
      expect(result.boardPresetName, 'Blitz');
      expect(result.rows, 4);
      expect(result.cols, 4);
    });

    test('fromCallable defaults missing preset fields to Classic', () {
      final result = CreateChallengeResult.fromCallable({'code': 'XYZ999'});

      expect(result.boardPresetId, ChallengeBoardPreset.defaultPresetId);
      expect(result.boardPresetName, 'Classic');
      expect(result.rows, 6);
      expect(result.cols, 6);
    });

    test('fromCallable throws when code missing', () {
      expect(
        () => CreateChallengeResult.fromCallable({'boardPresetId': 'x'}),
        throwsFormatException,
      );
    });
  });
}
