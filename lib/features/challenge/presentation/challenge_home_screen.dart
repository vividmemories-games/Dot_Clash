import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';
import '../domain/challenge_exceptions.dart';
import '../providers/challenge_providers.dart';
import 'challenge_rechallenge_mixin.dart';
import 'join_challenge_sheet.dart';
import 'widgets/challenge_history_widgets.dart';

/// Challenge mode hub — Create, Join, and rivalries.
class ChallengeHomeScreen extends ConsumerStatefulWidget {
  const ChallengeHomeScreen({super.key});

  @override
  ConsumerState<ChallengeHomeScreen> createState() =>
      _ChallengeHomeScreenState();
}

class _ChallengeHomeScreenState extends ConsumerState<ChallengeHomeScreen>
    with ChallengeRechallengeMixin {
  bool _creating = false;

  Future<void> _createChallenge() async {
    if (_creating || challengingUid != null) return;
    setState(() => _creating = true);
    try {
      final code =
          await ref.read(challengeRepositoryProvider).createChallenge();
      if (!mounted) return;
      context.push(AppRoutes.challengeLobbyPath(code));
    } on ChallengeException catch (e) {
      if (mounted) AppSnackBar.show(context, e.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final size = MediaQuery.sizeOf(context);
    final rivalsAsync = ref.watch(challengeRivalsProvider);
    final actionsBusy = _creating || challengingUid != null;

    return Scaffold(
      backgroundColor: v.scaffold,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: v.textPrimary,
        title: Text(
          'CHALLENGE A FRIEND',
          style: t.playerName.copyWith(fontSize: 14),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/challenge_home_backdrop.png',
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            errorBuilder: (_, __, ___) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 1.1,
                  colors: [
                    v.gold.withValues(alpha: 0.12),
                    v.scaffold,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    v.scaffold.withValues(alpha: 0.92),
                    v.scaffold.withValues(alpha: 0.78),
                    v.scaffold.withValues(alpha: 0.94),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: v.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: v.gold.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Icon(Icons.groups_rounded, color: v.gold),
                      ),
                      AppSpacing.hGapMD,
                      Expanded(
                        child: Text(
                          'Live 6×6 online — no lives or coins',
                          style: t.bodySmall.copyWith(color: v.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapLG,
                  Row(
                    children: [
                      Expanded(
                        child: NeonButton(
                          label: _creating ? 'CREATING…' : 'CREATE',
                          icon: Icons.add_rounded,
                          color: v.playerA,
                          height: 48,
                          enabled: !actionsBusy,
                          onPressed: actionsBusy ? null : _createChallenge,
                        ),
                      ),
                      AppSpacing.hGapSM,
                      Expanded(
                        child: NeonButton(
                          label: 'JOIN',
                          icon: Icons.login_rounded,
                          color: v.playerB,
                          height: 48,
                          enabled: !actionsBusy,
                          onPressed: actionsBusy
                              ? null
                              : () => showJoinChallengeSheet(context),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapLG,
                  Text('RIVALRIES', style: t.scoreLabel),
                  AppSpacing.vGapSM,
                  rivalsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const ChallengeRivalriesEmptyCard(),
                    data: (rivals) {
                      if (rivals.isEmpty) {
                        return const ChallengeRivalriesEmptyCard();
                      }

                      return Column(
                        children: [
                          for (final rival in rivals) ...[
                            RivalListTile(
                              rival: rival,
                              busy: challengingUid == rival.uid,
                              enabled: challengingUid == null && !_creating,
                              onRechallenge: () => rechallenge(rival.uid),
                            ),
                            AppSpacing.vGapSM,
                          ],
                        ],
                      );
                    },
                  ),
                  AppSpacing.vGapMD,
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: v.textPrimary,
                        side: BorderSide(color: v.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.roundedMD,
                        ),
                      ),
                      onPressed: () => context.push(AppRoutes.challengeHistory),
                      child: Text(
                        'VIEW ALL RIVALRIES',
                        style: t.scoreLabel.copyWith(
                          fontSize: 10,
                          color: v.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
