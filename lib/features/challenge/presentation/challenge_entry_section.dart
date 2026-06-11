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
import 'join_challenge_sheet.dart';

/// Home entry below [HomeActionRow] — Create or Join by code (Phase 4 expands this).
class ChallengeEntrySection extends ConsumerStatefulWidget {
  const ChallengeEntrySection({super.key});

  @override
  ConsumerState<ChallengeEntrySection> createState() =>
      _ChallengeEntrySectionState();
}

class _ChallengeEntrySectionState extends ConsumerState<ChallengeEntrySection> {
  bool _creating = false;

  Future<void> _createChallenge() async {
    if (_creating) return;
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.gold.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          colors: [
            v.surfaceElevated,
            Color.lerp(v.surfaceElevated, v.gold, 0.06)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_rounded, color: v.gold, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'CHALLENGE A FRIEND',
                style: t.playerName.copyWith(color: v.gold, fontSize: 13),
              ),
            ],
          ),
          AppSpacing.vGapXS,
          Text(
            'Live 6×6 online — no lives or coins',
            style: t.bodySmall.copyWith(color: v.textSecondary),
          ),
          AppSpacing.vGapMD,
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: _creating ? 'CREATING…' : 'CREATE',
                  icon: Icons.add_rounded,
                  color: v.playerA,
                  height: 48,
                  enabled: !_creating,
                  onPressed: _creating ? null : _createChallenge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: NeonButton(
                  label: 'JOIN',
                  icon: Icons.login_rounded,
                  color: v.playerB,
                  height: 48,
                  onPressed: () => showJoinChallengeSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
