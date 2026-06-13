import 'package:dot_clash/core/deep_links/challenge_link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChallengeLinkParser', () {
    test('parses HTTPS join link', () {
      final uri = Uri.parse(
        'https://vividmemories-games.github.io/join/abc123',
      );
      expect(ChallengeLinkParser.parseChallengeCode(uri), 'ABC123');
    });

    test('parses custom scheme join link', () {
      final uri = Uri.parse('dotclash://join/XY12Z9');
      expect(ChallengeLinkParser.parseChallengeCode(uri), 'XY12Z9');
    });

    test('rejects invalid code length', () {
      final uri = Uri.parse('dotclash://join/ABC');
      expect(ChallengeLinkParser.parseChallengeCode(uri), isNull);
    });

    test('parses FCM challenge_invite payload', () {
      expect(
        ChallengeLinkParser.parseFcmData({
          'type': 'challenge_invite',
          'code': 'cljf9d',
        }),
        'CLJF9D',
      );
    });

    test('ignores unrelated FCM type', () {
      expect(
        ChallengeLinkParser.parseFcmData({'type': 'other', 'code': 'ABC123'}),
        isNull,
      );
    });
  });
}
