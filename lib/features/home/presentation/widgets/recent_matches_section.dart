import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/home/domain/home_ui_models.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/neon_card.dart';

class RecentMatchesSection extends StatelessWidget {
  const RecentMatchesSection({super.key, required this.matches});

  final List<RecentMatch> matches;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENT MATCHES', style: t.scoreLabel),
        AppSpacing.vGapSM,
        NeonCard(
          glowColor: v.green.withOpacity(0.08),
          child: Column(
            children: matches
                .map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _MatchRow(match: match),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

  final RecentMatch match;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final (label, color, icon) = switch (match.outcome) {
      MatchOutcome.win => ('WIN', v.green, Icons.check_circle_outline_rounded),
      MatchOutcome.loss => ('LOSS', v.red, Icons.cancel_outlined),
      MatchOutcome.tie => ('TIE', v.gold, Icons.remove_circle_outline_rounded),
    };

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        AppSpacing.hGapSM,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · ${match.modeLabel}',
                style: t.playerName.copyWith(color: color),
              ),
              Text('vs ${match.opponentLabel}', style: t.bodySmall),
            ],
          ),
        ),
        Text(_relative(match.playedAt), style: t.bodySmall),
      ],
    );
  }

  static String _relative(DateTime when) {
    final delta = DateTime.now().difference(when);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }
}
