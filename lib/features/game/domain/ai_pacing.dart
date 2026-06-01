/// Timing for opponent moves — keep [edgeDrawMs] in sync with [BoardWidget] edge anim.
abstract final class AiPacing {
  static const int edgeDrawMs = 320;
  static const int boxClaimMs = 420;
  static const int readBeatMs = 350;

  /// Pause before the opponent's first line after you finish your turn.
  static const int thinkBeforeFirstMs = 1000;

  /// Wait for draw animation + brief read time before the next line in a chain.
  static int get afterAiMoveMs => edgeDrawMs + readBeatMs;

  /// Brief pause when control returns to the human so the board can be scanned.
  static const int handoffToHumanMs = 400;
}
