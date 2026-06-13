/// Nostalgia share copy for post-win challenge results (clipboard).
abstract final class ChallengeWinShare {
  static String buildText({
    required String opponentName,
    required int myScore,
    required int opponentScore,
    String? seriesDisplay,
  }) {
    final seriesPart = seriesDisplay != null && seriesDisplay.isNotEmpty
        ? ' Series: $seriesDisplay.'
        : '';
    return 'Remember this game from class? '
        'I beat $opponentName $myScore–$opponentScore in Dot Clash!'
        '$seriesPart Challenge me back in the app.';
  }
}
