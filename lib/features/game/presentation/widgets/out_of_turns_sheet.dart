import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/neon_button.dart';

class OutOfTurnsSheet extends StatelessWidget {
  const OutOfTurnsSheet({
    super.key,
    required this.canWatchAd,
    required this.hasExtraTurnBoost,
    required this.onWatchAd,
    required this.onUseBoost,
    required this.onGiveUp,
  });

  final bool canWatchAd;
  final bool hasExtraTurnBoost;
  final Future<void> Function() onWatchAd;
  final Future<void> Function() onUseBoost;
  final VoidCallback onGiveUp;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.vGapSM,
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: v.cardBorder,
                borderRadius: AppSpacing.roundedFull,
              ),
            ),
          ),
          AppSpacing.vGapMD,
          Text(
            'OUT OF TURNS',
            style: t.playerName.copyWith(color: v.red, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapSM,
          Text(
            'You used every turn. Watch an ad or spend a boost to keep playing, '
            'or end the match now.',
            style: t.bodySmall,
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapMD,
          if (canWatchAd)
            NeonButton(
              label: 'Watch ad · +3 turns',
              icon: Icons.play_circle_outline_rounded,
              color: v.gold,
              onPressed: () async {
                await onWatchAd();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          if (hasExtraTurnBoost) ...[
            AppSpacing.vGapSM,
            NeonButton(
              label: 'Use Extra Turns (+3)',
              icon: Icons.add_circle_outline_rounded,
              color: v.playerA,
              onPressed: () async {
                await onUseBoost();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
          AppSpacing.vGapSM,
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onGiveUp();
            },
            child: Text(
              'END MATCH',
              style: t.bodySmall.copyWith(color: v.textSecondary),
            ),
          ),
          AppSpacing.vGapMD,
        ],
      ),
    );
  }
}
