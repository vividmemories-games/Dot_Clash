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
import '../domain/head_to_head_stats.dart';
import '../providers/challenge_providers.dart';
import 'join_challenge_sheet.dart';

/// Challenge mode hub — Create, Join, and recent rivals.
class ChallengeHomeScreen extends ConsumerStatefulWidget {
  const ChallengeHomeScreen({super.key});

  @override
  ConsumerState<ChallengeHomeScreen> createState() =>
      _ChallengeHomeScreenState();
}

class _ChallengeHomeScreenState extends ConsumerState<ChallengeHomeScreen> {
  bool _creating = false;
  String? _challengingUid;

  Future<void> _createChallenge({String? targetUid}) async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _challengingUid = targetUid;
    });
    try {
      final code = await ref.read(challengeRepositoryProvider).createChallenge(
            targetUid: targetUid,
          );
      if (!mounted) return;
      context.push(AppRoutes.challengeLobbyPath(code));
    } on ChallengeException catch (e) {
      if (mounted) AppSnackBar.show(context, e.message);
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
          _challengingUid = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final size = MediaQuery.sizeOf(context);
    final rivalsAsync = ref.watch(challengeRivalsProvider);
    final rivals = rivalsAsync.valueOrNull ?? const <ChallengeRival>[];

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
                          label: _creating && _challengingUid == null
                              ? 'CREATING…'
                              : 'CREATE',
                          icon: Icons.add_rounded,
                          color: v.playerA,
                          height: 48,
                          enabled: !_creating,
                          onPressed: _creating ? null : _createChallenge,
                        ),
                      ),
                      AppSpacing.hGapSM,
                      Expanded(
                        child: NeonButton(
                          label: 'JOIN',
                          icon: Icons.login_rounded,
                          color: v.playerB,
                          height: 48,
                          enabled: !_creating,
                          onPressed: _creating
                              ? null
                              : () => showJoinChallengeSheet(context),
                        ),
                      ),
                    ],
                  ),
                  if (rivals.isNotEmpty) ...[
                    AppSpacing.vGapLG,
                    Text(
                      'RECENT RIVALS',
                      style: t.scoreLabel.copyWith(
                        fontSize: 10,
                        color: v.textSecondary,
                      ),
                    ),
                    AppSpacing.vGapSM,
                    ...rivals.map(
                      (rival) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _RivalTile(
                          rival: rival,
                          busy: _creating && _challengingUid == rival.uid,
                          enabled: !_creating,
                          onTap: () => _createChallenge(targetUid: rival.uid),
                        ),
                      ),
                    ),
                  ],
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

class _RivalTile extends StatelessWidget {
  const _RivalTile({
    required this.rival,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final ChallengeRival rival;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Material(
      color: v.surface.withValues(alpha: 0.72),
      borderRadius: AppSpacing.roundedMD,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppSpacing.roundedMD,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.sports_esports_rounded, color: v.gold, size: 18),
              AppSpacing.hGapSM,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rival.displayName,
                      style: t.playerName.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Series ${rival.record.display}',
                      style: t.bodySmall.copyWith(
                        fontSize: 10,
                        color: v.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: v.gold,
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: v.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
