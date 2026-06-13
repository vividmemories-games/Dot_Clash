import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../services/ads/ad_service_provider.dart';
import '../../../services/analytics/analytics_service.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';
import '../../game/domain/models/game_state.dart';
import '../../home/domain/home_ui_models.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/challenge_match_result.dart';
import '../domain/challenge_exceptions.dart';
import '../domain/challenge_room.dart';
import '../domain/challenge_status.dart';
import '../domain/challenge_win_share.dart';
import '../domain/head_to_head_stats.dart';
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
  bool _checkedInitialTerminal = false;

  String get _code => widget.code.trim().toUpperCase();

  GameState _gameStateFor(ChallengeRoom room) {
    final fromRoom = room.gameState;
    if (fromRoom != null) return fromRoom;
    return ref.read(challengeGameProvider(_code));
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(challengeRoomProvider(_code));
    if (!_checkedInitialTerminal) {
      _checkedInitialTerminal = true;
      final room = roomAsync.valueOrNull;
      if (room != null && _shouldSettle(room) && !_settled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _settled) return;
          unawaited(_settle(room, showDialog: false));
        });
      }
    }

    ref.listen(challengeRoomProvider(_code), (prev, next) {
      final room = next.valueOrNull;
      if (room == null || _settled) return;
      if (!_shouldSettle(room)) return;

      final prevRoom = prev?.valueOrNull;
      final showDialog =
          prevRoom != null && !_shouldSettle(prevRoom) && _shouldSettle(room);
      unawaited(_settle(room, showDialog: showDialog));
    });
    return widget.child;
  }

  bool _shouldSettle(ChallengeRoom room) {
    return room.status == ChallengeStatus.finished ||
        room.status == ChallengeStatus.abandoned;
  }

  Future<void> _settle(ChallengeRoom room, {required bool showDialog}) async {
    if (_settled) return;
    _settled = true;

    final myUid = ref.read(currentUserProvider)?.uid;
    final myPlayerId = room.playerIdForUid(myUid ?? '') ?? 'A';
    final gameState = _gameStateFor(room);
    final opponent = room.opponentDisplayNameFor(myUid ?? '');
    final result = challengeMatchResult(room, myUid);

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

    final outcomeLabel = switch (result) {
      MatchResult.win => 'win',
      MatchResult.loss => 'loss',
      MatchResult.tie => 'tie',
    };
    unawaited(
      AnalyticsService.instance.logChallengeFinished(
        code: _code,
        result: outcomeLabel,
        moveCount: gameState.moveHistory.length,
      ),
    );

    if (!showDialog || _dialogShown) return;
    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showResultDialog(room, gameState, myPlayerId, result);
    });
  }

  MatchOutcome _outcomeFromResult(MatchResult result) {
    return switch (result) {
      MatchResult.win => MatchOutcome.win,
      MatchResult.loss => MatchOutcome.loss,
      MatchResult.tie => MatchOutcome.tie,
    };
  }

  Future<void> _startRematch({
    required BuildContext dialogContext,
    required String opponentUid,
  }) async {
    try {
      final code = await ref
          .read(challengeRepositoryProvider)
          .createChallenge(targetUid: opponentUid);
      if (!dialogContext.mounted) return;
      dialogContext.push(AppRoutes.challengeLobbyPath(code));
    } on ChallengeException catch (e) {
      if (dialogContext.mounted) {
        AppSnackBar.show(dialogContext, e.message);
      }
    }
  }

  void _showResultDialog(
    ChallengeRoom room,
    GameState gameState,
    String myPlayerId,
    MatchResult result,
  ) {
    final rootContext = ref.read(rootNavigatorKeyProvider).currentContext;
    final dialogContext = rootContext ?? context;
    if (!dialogContext.mounted) return;

    final v = dialogContext.dc;
    final t = dialogContext.txt;
    final settings = ref.read(settingsProvider);
    final myUid = ref.read(currentUserProvider)?.uid ?? '';
    final opponent = room.opponentDisplayNameFor(myUid);
    final opponentUid = room.opponentUidFor(myUid);
    final myName = settings.youName.trim().isEmpty ? 'You' : settings.youName;

    final labels = challengeResultLabels(room, myUid);
    final iWon = labels.iWon;
    final isTie = labels.isTie;

    final headline = isTie
        ? "It's a Tie!"
        : iWon
            ? 'You Win!'
            : '$opponent Wins!';
    final subline = room.status == ChallengeStatus.abandoned
        ? (isTie
            ? 'Match expired after inactivity.'
            : (iWon ? 'Opponent left the match.' : 'Match abandoned.'))
        : (isTie ? 'Perfectly matched.' : (iWon ? 'Nice boxes!' : 'Rematch?'));
    final color = isTie ? v.gold : (iWon ? v.playerA : v.playerB);

    final myScore = gameState.scoreOf(myPlayerId);
    final oppId = myPlayerId == 'A' ? 'B' : 'A';
    final oppScore = gameState.scoreOf(oppId);

    HeadToHeadRecord? h2h;
    if (opponentUid != null) {
      final prior =
          ref.read(challengeRecentMatchesProvider).valueOrNull ?? const [];
      h2h = HeadToHeadStats.forOpponent(
        prior,
        opponentUid,
        includeCurrent: _outcomeFromResult(result),
      );
    }

    final canRematch = opponentUid != null && opponentUid.isNotEmpty;
    final canShareWin = iWon && room.status != ChallengeStatus.abandoned;

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
            if (h2h != null && h2h.hasHistory) ...[
              AppSpacing.vGapSM,
              Text(
                'Series: ${h2h.display}',
                style: t.scoreLabel.copyWith(color: v.gold, fontSize: 11),
              ),
            ],
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
          if (canShareWin)
            TextButton(
              onPressed: () async {
                final text = ChallengeWinShare.buildText(
                  opponentName: opponent,
                  myScore: myScore,
                  opponentScore: oppScore,
                  seriesDisplay:
                      h2h != null && h2h.hasHistory ? h2h.display : null,
                );
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) {
                  AppSnackBar.show(ctx, 'Win share copied');
                }
              },
              child: const Text('Share'),
            ),
          if (canRematch)
            TextButton(
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop();
                unawaited(
                  _startRematch(
                    dialogContext: dialogContext,
                    opponentUid: opponentUid,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: v.gold),
              child: const Text('Rematch'),
            ),
        ],
      ),
    );
  }
}
