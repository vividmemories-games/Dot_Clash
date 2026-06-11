/// Server-written challenge room lifecycle (`challenges/{code}.status`).
enum ChallengeStatus {
  waiting,
  active,
  finished,
  expired,
  abandoned;

  bool get isTerminal =>
      this == finished || this == expired || this == abandoned;

  static ChallengeStatus parse(String raw) {
    return ChallengeStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => ChallengeStatus.expired,
    );
  }
}
