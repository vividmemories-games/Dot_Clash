import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';
import '../domain/challenge_board_preset.dart';
import '../domain/challenge_exceptions.dart';
import '../domain/challenge_room.dart';
import '../domain/challenge_status.dart';
import '../providers/challenge_providers.dart';
import 'challenge_share_sheet.dart';
import 'widgets/challenge_board_preview_card.dart';

/// Waiting room — listens to `challenges/{code}` and routes to play when active.
class ChallengeLobbyScreen extends ConsumerStatefulWidget {
  const ChallengeLobbyScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ChallengeLobbyScreen> createState() =>
      _ChallengeLobbyScreenState();
}

class _ChallengeLobbyScreenState extends ConsumerState<ChallengeLobbyScreen> {
  bool _joining = false;
  bool _navigatedToPlay = false;

  String get _code => widget.code.trim().toUpperCase();

  Future<void> _joinChallenge() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await ref.read(challengeRepositoryProvider).joinChallenge(_code);
    } on ChallengeException catch (e) {
      if (mounted) AppSnackBar.show(context, e.message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _maybeNavigateToPlay(ChallengeRoom? room) {
    if (_navigatedToPlay || room == null || !room.isActive) return;
    _navigatedToPlay = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.challengePlayPath(_code));
    });
  }

  ChallengeBoardPreset _presetFor(ChallengeRoom room) => room.boardPreset;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final myUid = ref.watch(currentUserProvider)?.uid;
    final roomAsync = ref.watch(challengeRoomProvider(_code));

    ref.listen(challengeRoomProvider(_code), (prev, next) {
      _maybeNavigateToPlay(next.valueOrNull);
    });

    return Scaffold(
      backgroundColor: v.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Challenge', style: t.playerName),
      ),
      body: roomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load room: $e')),
        data: (room) {
          if (room == null) {
            return _MessageBody(
              title: 'Not found',
              subtitle: 'This challenge code is invalid or expired.',
              v: v,
              t: t,
            );
          }

          if (room.isTerminal) {
            return _MessageBody(
              title: _terminalTitle(room.status),
              subtitle: _terminalSubtitle(room, myUid),
              v: v,
              t: t,
              actionLabel: 'BACK HOME',
              onAction: () => context.go(AppRoutes.home),
            );
          }

          final isHost = myUid == room.hostUid;
          final isGuest = myUid == room.guestUid;
          final isProspectiveGuest =
              !isHost && room.isWaiting && room.guestUid == null;
          final preset = _presetFor(room);

          return Padding(
            padding: AppSpacing.pagePadding,
            child: Column(
              children: [
                AppSpacing.vGapMD,
                Text(
                  _code,
                  style: t.heroTitle.copyWith(
                    fontSize: 40,
                    letterSpacing: 6,
                    color: v.playerA,
                  ),
                ),
                AppSpacing.vGapSM,
                Text(
                  _statusLine(room, isHost, isProspectiveGuest),
                  style: t.body.copyWith(color: v.textSecondary),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.vGapLG,
                ChallengeBoardPreviewCard(
                  preset: preset,
                  eyebrow: isProspectiveGuest ? 'THEIR BOARD' : 'YOUR BOARD',
                  showFairnessLine: isProspectiveGuest,
                  showThumbnail: true,
                ),
                if (!isProspectiveGuest) ...[
                  AppSpacing.vGapLG,
                  _PlayerCard(
                    label: 'YOU',
                    name: isHost
                        ? room.hostDisplayName
                        : (room.guestDisplayName ?? 'You'),
                    color: v.playerA,
                    v: v,
                    t: t,
                  ),
                  AppSpacing.vGapSM,
                  Icon(Icons.close_rounded, color: v.textSecondary, size: 20),
                  AppSpacing.vGapSM,
                  _PlayerCard(
                    label: isHost ? 'OPPONENT' : 'HOST',
                    name: room.opponentDisplayNameFor(myUid ?? ''),
                    color: v.playerB,
                    v: v,
                    t: t,
                  ),
                ],
                const Spacer(),
                if (_joining)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                if (isProspectiveGuest && room.isWaiting) ...[
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: _joining ? 'JOINING…' : 'JOIN CHALLENGE',
                      icon: Icons.login_rounded,
                      color: v.playerB,
                      enabled: !_joining,
                      onPressed: _joining ? null : _joinChallenge,
                    ),
                  ),
                  AppSpacing.vGapSM,
                  TextButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: Text(
                      'NOT NOW',
                      style: t.bodySmall.copyWith(color: v.textSecondary),
                    ),
                  ),
                ] else if (isHost && room.isWaiting) ...[
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: 'SHARE CODE',
                      icon: Icons.share_rounded,
                      color: v.playerA,
                      onPressed: () => showChallengeShareSheet(
                        context: context,
                        code: _code,
                        hostDisplayName: room.hostDisplayName,
                      ),
                    ),
                  ),
                  AppSpacing.vGapSM,
                  TextButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: Text(
                      'CANCEL',
                      style: t.bodySmall.copyWith(color: v.textSecondary),
                    ),
                  ),
                ] else if (room.isActive && (isHost || isGuest)) ...[
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: 'ENTER MATCH',
                      icon: Icons.sports_esports_outlined,
                      color: v.green,
                      onPressed: () =>
                          context.go(AppRoutes.challengePlayPath(_code)),
                    ),
                  ),
                  AppSpacing.vGapSM,
                ],
                AppSpacing.vGapMD,
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLine(
    ChallengeRoom room,
    bool isHost,
    bool isProspectiveGuest,
  ) {
    if (isProspectiveGuest) {
      return '${room.hostDisplayName} challenged you';
    }
    if (room.isWaiting) return 'Waiting for opponent…';
    return 'Starting match…';
  }

  String _terminalTitle(ChallengeStatus status) {
    return switch (status) {
      ChallengeStatus.finished => 'Match finished',
      ChallengeStatus.abandoned => 'Challenge ended',
      ChallengeStatus.expired => 'Challenge expired',
      _ => 'Challenge ended',
    };
  }

  String _terminalSubtitle(ChallengeRoom room, String? myUid) {
    if (room.status == ChallengeStatus.abandoned && room.winnerUid != null) {
      if (myUid == room.winnerUid) return 'You win — opponent left.';
      return 'You left or opponent wins.';
    }
    return 'This room is closed.';
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.label,
    required this.name,
    required this.color,
    required this.v,
    required this.t,
  });

  final String label;
  final String name;
  final Color color;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: v.surfaceElevated,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(label, style: t.bodySmall.copyWith(color: color)),
          AppSpacing.vGapXS,
          Text(
            name,
            style: t.playerName.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.title,
    required this.subtitle,
    required this.v,
    required this.t,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final DotClashVisuals v;
  final AppTextStyles t;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: t.heroTitle.copyWith(fontSize: 24)),
          AppSpacing.vGapSM,
          Text(
            subtitle,
            style: t.body.copyWith(color: v.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            AppSpacing.vGapLG,
            NeonButton(
              label: actionLabel!,
              color: v.playerA,
              width: double.infinity,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
