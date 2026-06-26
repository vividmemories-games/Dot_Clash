import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/analytics/analytics_service.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../game/domain/models/game_state.dart';
import '../../game/presentation/game_screen.dart';
import '../domain/challenge_room.dart';
import '../domain/challenge_status.dart';
import '../providers/challenge_providers.dart';
import 'challenge_game_bindings.dart';

/// Live challenge match — [GameScreen] in [GameMode.challenge].
class ChallengePlayScreen extends ConsumerStatefulWidget {
  const ChallengePlayScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ChallengePlayScreen> createState() =>
      _ChallengePlayScreenState();
}

class _ChallengePlayScreenState extends ConsumerState<ChallengePlayScreen> {
  /// Once the board is shown, keep [GameScreen] mounted through `finished`.
  bool _playSessionLocked = false;
  bool _startedLogged = false;

  String get _normalized => widget.code.trim().toUpperCase();

  void _logStartedOnce() {
    if (_startedLogged) return;
    _startedLogged = true;
    unawaited(
      AnalyticsService.instance.logChallengeStarted(code: _normalized),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final roomAsync = ref.watch(challengeRoomProvider(_normalized));
    final myUid = ref.watch(currentUserProvider)?.uid;

    return roomAsync.when(
      loading: () => Scaffold(
        backgroundColor: v.scaffold,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: v.scaffold,
        body: Center(child: Text('Error: $e')),
      ),
      data: (room) {
        if (room != null && room.hasPlayableBoard) {
          _playSessionLocked = true;
        }

        if (room != null &&
            (_playSessionLocked || room.hasPlayableBoard) &&
            room.gameState != null) {
          _logStartedOnce();
          final myPlayerId = room.playerIdForUid(myUid ?? '') ?? 'A';
          final config = GameConfig.challenge(
            code: _normalized,
            myPlayerId: myPlayerId,
            opponentDisplayName: room.opponentDisplayNameFor(myUid ?? ''),
            rows: room.rows,
            cols: room.cols,
            disabledCells: room.gameState!.disabledCells.toList(),
          );

          return ChallengeGameBindings(
            code: _normalized,
            child: GameScreen(
              key: ValueKey('challenge-$_normalized'),
              config: config,
            ),
          );
        }

        return Scaffold(
          backgroundColor: v.scaffold,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('Challenge $_normalized', style: t.playerName),
          ),
          body: Center(
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _idleTitle(room),
                    style: t.heroTitle.copyWith(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.vGapSM,
                  Text(
                    _idleSubtitle(room),
                    style: t.body.copyWith(color: v.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.vGapMD,
                  NeonButton(
                    label: room?.isWaiting == true ? 'LOBBY' : 'HOME',
                    color: v.playerA,
                    width: double.infinity,
                    onPressed: () {
                      if (room?.isWaiting == true) {
                        context.go(AppRoutes.challengeLobbyPath(_normalized));
                      } else {
                        context.go(AppRoutes.home);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _idleTitle(ChallengeRoom? room) {
    if (room == null) return 'Not found';
    return switch (room.status) {
      ChallengeStatus.waiting => 'Waiting for opponent',
      ChallengeStatus.expired => 'Challenge expired',
      ChallengeStatus.finished => 'Match finished',
      ChallengeStatus.abandoned => 'Challenge ended',
      ChallengeStatus.active => 'Room not ready',
    };
  }

  String _idleSubtitle(ChallengeRoom? room) {
    if (room == null) {
      return 'This challenge code is invalid or was removed.';
    }
    return switch (room.status) {
      ChallengeStatus.waiting => 'Return to the lobby while your friend joins.',
      ChallengeStatus.expired => 'Create a new challenge from home.',
      ChallengeStatus.finished ||
      ChallengeStatus.abandoned =>
        'Return home to start another match.',
      ChallengeStatus.active => 'Return to the lobby or home.',
    };
  }
}
