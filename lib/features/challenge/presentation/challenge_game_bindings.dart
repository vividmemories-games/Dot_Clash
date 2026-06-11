import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../services/ads/ad_service_provider.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';
import '../../game/domain/models/game_state.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/challenge_room.dart';
import '../domain/challenge_status.dart';
import '../providers/challenge_game_provider.dart';
import '../providers/challenge_providers.dart';

/// Listens to challenge room terminal status and settles the match outside
/// [GameScreen]'s local [gameProvider] listener.
class ChallengeGameBindings extends ConsumerStatefulWidget {
  const ChallengeGameBindings({
    super.key,
    required this.code,
    required this.child,
  });

  final String code;
  final Widget child;

  @override
  ConsumerState<ChallengeGameBindings> createState() =>
      _ChallengeGameBindingsState();
}

class _ChallengeGameBindingsState extends ConsumerState<ChallengeGameBindings> {
  bool _settled = false;
  bool _dialogShown = false;

  String get _code => widget.code.trim().toUpperCase();

  @override
  Widget build(BuildContext context) {
    ref.listen(challengeRoomProvider(_code), (prev, next) {
      final room = next.valueOrNull;
      if (room == null || _settled) return;
      if (!_shouldSettle(room)) return;
      unawaited(_settle(room));
    });
    return widget.child;
  }

  bool _shouldSettle(ChallengeRoom room) {
    return room.status == ChallengeStatus.finished ||
        (room.status == ChallengeStatus.abandoned && room.winnerUid != null);
  }

  Future<void> _settle(ChallengeRoom room) async {
    if (_settled) return;
    _settled = true;

    final myUid = ref.read(currentUserProvider)?.uid;
    final myPlayerId = room.playerIdForUid(myUid ?? '') ?? 'A';
    final gameState = ref.read(challengeGameProvider(_code));
    final opponent = room.opponentDisplayNameFor(myUid ?? '');
    final result = _matchResult(room, gameState, myPlayerId, myUid);

    final repo = ref.read(profileRepositoryProvider);
    try {
      await repo.recordChallengeMatch(
        code: _code,
        result: result,
        opponentLabel: opponent,
      );
    } catch (e, st) {
      debugPrint('[Challenge][recordChallengeMatch] failed=$e $st');
    }

    if (_dialogShown) return;
    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showResultDialog(room, gameState, myPlayerId);
    });
  }

  MatchResult _matchResult(
    ChallengeRoom room,
    GameState gameState,
    String myPlayerId,
    String? myUid,
  ) {
    if (room.status == ChallengeStatus.abandoned) {
      return room.winnerUid == myUid ? MatchResult.win : MatchResult.loss;
    }
    if (gameState.isTie) return MatchResult.tie;
    if (gameState.winnerId == myPlayerId) return MatchResult.win;
    return MatchResult.loss;
  }

  void _showResultDialog(
    ChallengeRoom room,
    GameState gameState,
    String myPlayerId,
  ) {
    final rootContext = ref.read(rootNavigatorKeyProvider).currentContext;
    final dialogContext = rootContext ?? context;
    if (!dialogContext.mounted) return;

    final v = dialogContext.dc;
    final t = dialogContext.txt;
    final settings = ref.read(settingsProvider);
    final opponent =
        room.opponentDisplayNameFor(ref.read(currentUserProvider)?.uid ?? '');
    final myName = settings.youName.trim().isEmpty ? 'You' : settings.youName;

    final bool iWon;
    final bool isTie;
    if (room.status == ChallengeStatus.abandoned) {
      iWon = room.winnerUid == ref.read(currentUserProvider)?.uid;
      isTie = false;
    } else {
      isTie = gameState.isTie;
      iWon = !isTie && gameState.winnerId == myPlayerId;
    }

    final headline = isTie
        ? "It's a Tie!"
        : iWon
            ? 'You Win!'
            : '$opponent Wins!';
    final subline = room.status == ChallengeStatus.abandoned
        ? (iWon ? 'Opponent left the match.' : 'Match abandoned.')
        : (isTie ? 'Perfectly matched.' : (iWon ? 'Nice boxes!' : 'Rematch?'));
    final color = isTie ? v.gold : (iWon ? v.playerA : v.playerB);

    final myScore = gameState.scoreOf(myPlayerId);
    final oppId = myPlayerId == 'A' ? 'B' : 'A';
    final oppScore = gameState.scoreOf(oppId);

    showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AlertDialog(
        backgroundColor: v.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedXL,
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        title: Text(headline, style: t.heroTitle.copyWith(color: color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subline, style: t.bodySmall, textAlign: TextAlign.center),
            AppSpacing.vGapMD,
            Text(
              '$myScore – $oppScore',
              style: t.scoreNumber.copyWith(fontSize: 28),
            ),
            AppSpacing.vGapXS,
            Text(
              '$myName vs $opponent',
              style: t.bodySmall.copyWith(color: v.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx, rootNavigator: true).pop();
              dialogContext.go(AppRoutes.home);
            },
            child: const Text('Home'),
          ),
        ],
      ),
    );
  }
}
