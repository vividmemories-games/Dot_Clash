/// Parses challenge invite URLs into a 6-character room code.
///
/// Supported forms:
/// - `https://vividmemories-games.github.io/join/ABC123`
/// - `dotclash://join/ABC123`
abstract final class ChallengeLinkParser {
  static const httpsHost = 'vividmemories-games.github.io';
  static final _codePattern = RegExp(r'^[A-Z0-9]{6}$');

  /// Returns an uppercase challenge code or `null` when [uri] is not a join link.
  static String? parseChallengeCode(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'dotclash' && uri.host.toLowerCase() == 'join') {
      final raw = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : uri.path.replaceFirst('/', '');
      return normalizeCode(raw);
    }

    if ((scheme == 'https' || scheme == 'http') &&
        uri.host.toLowerCase() == httpsHost) {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments.first.toLowerCase() == 'join') {
        return normalizeCode(segments[1]);
      }
    }

    return null;
  }

  /// FCM `data` payloads use `code` directly (see `sendChallengeInvitePush`).
  static String? parseFcmData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type != null && type != 'challenge_invite') return null;
    return normalizeCode(data['code']?.toString());
  }

  static String? normalizeCode(String? raw) {
    if (raw == null) return null;
    final code = raw.trim().toUpperCase();
    if (!_codePattern.hasMatch(code)) return null;
    return code;
  }
}
