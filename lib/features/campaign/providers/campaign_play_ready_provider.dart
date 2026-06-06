import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set when [GameScreen] has applied config and shows a fresh (not over) board.
/// Used to pop the victory overlay only after the next level is ready.
final campaignPlayReadyProvider = StateProvider<String?>((ref) => null);
