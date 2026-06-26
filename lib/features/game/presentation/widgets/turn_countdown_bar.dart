import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../domain/models/match_session.dart';

/// Shows remaining human turns for budgeted campaign levels.
class TurnCountdownBar extends StatelessWidget {
  const TurnCountdownBar({
    super.key,
    required this.session,
  });

  final MatchSession session;

  @override
  Widget build(BuildContext context) {
    if (!session.hasTurnBudget) return const SizedBox.shrink();

    final v = context.dc;
    final t = context.txt;
    final remaining = session.turnsRemaining ?? 0;
    final total = session.turnBudget ?? remaining;
    final ratio = total > 0 ? remaining / total : 0.0;
    final isLow = remaining <= 3;
    final isCritical = remaining <= 1;
    final barColor = isCritical ? v.red : (isLow ? v.gold : v.playerA);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: v.surface,
          borderRadius: AppSpacing.roundedMD,
          border: Border.all(
            color: barColor.withValues(alpha: isLow ? 0.45 : 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded, size: 16, color: barColor),
            AppSpacing.hGapXS,
            Text(
              'TURNS LEFT',
              style: t.turnLabel.copyWith(
                color: v.textSecondary,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              '$remaining / $total',
              style: t.timerText.copyWith(
                color: barColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            AppSpacing.hGapSM,
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: AppSpacing.roundedFull,
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: v.cardBorder,
                  color: barColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
