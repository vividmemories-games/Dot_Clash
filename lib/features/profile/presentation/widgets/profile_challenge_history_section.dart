import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/home/domain/home_ui_models.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../providers/profile_providers.dart';

/// Recent 1v1 challenge results from `profiles/{uid}/matches`.
class ProfileChallengeHistorySection extends ConsumerWidget {
  const ProfileChallengeHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final matchesAsync = ref.watch(challengeRecentMatchesProvider);

    return matchesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (matches) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FRIEND CHALLENGES', style: t.scoreLabel),
            AppSpacing.vGapSM,
            if (matches.isEmpty)
              _EmptyCard(v: v, t: t)
            else
              ...matches.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ChallengeMatchTile(match: m, v: v, t: t),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.v, required this.t});

  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No challenges yet',
            style: t.playerName.copyWith(fontSize: 15),
          ),
          AppSpacing.vGapXS,
          Text(
            'Remember this game from class? Challenge a friend from Home.',
            style: t.bodySmall.copyWith(color: v.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ChallengeMatchTile extends StatelessWidget {
  const _ChallengeMatchTile({
    required this.match,
    required this.v,
    required this.t,
  });

  final RecentMatch match;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    final accent = switch (match.outcome) {
      MatchOutcome.win => v.green,
      MatchOutcome.loss => v.red,
      MatchOutcome.tie => v.gold,
    };
    final outcomeLabel = switch (match.outcome) {
      MatchOutcome.win => 'WIN',
      MatchOutcome.loss => 'LOSS',
      MatchOutcome.tie => 'TIE',
    };
    final icon = switch (match.outcome) {
      MatchOutcome.win => Icons.emoji_events_rounded,
      MatchOutcome.loss => Icons.close_rounded,
      MatchOutcome.tie => Icons.handshake_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          AppSpacing.hGapSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${match.opponentLabel}',
                  style: t.playerName.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _relativePlayedAt(match.playedAt),
                  style: t.bodySmall.copyWith(
                    fontSize: 10,
                    color: v.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppSpacing.roundedFull,
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              outcomeLabel,
              style: t.scoreLabel.copyWith(color: accent, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static String _relativePlayedAt(DateTime playedAt) {
    final diff = DateTime.now().difference(playedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${playedAt.month}/${playedAt.day}/${playedAt.year}';
  }
}
