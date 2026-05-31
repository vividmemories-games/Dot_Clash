import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/match_session.dart';

final matchSessionProvider =
    StateNotifierProvider.autoDispose<MatchSessionNotifier, MatchSession>(
  (ref) => MatchSessionNotifier(),
);

class MatchSessionNotifier extends StateNotifier<MatchSession> {
  MatchSessionNotifier() : super(const MatchSession());

  void init({int? turnBudget}) {
    state = MatchSession(
      turnBudget: turnBudget,
      turnsRemaining: turnBudget,
    );
  }

  void reset() => state = const MatchSession();

  void update(MatchSession session) => state = session;
}
