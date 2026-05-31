import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/neon_button.dart';

void showGameRulesSheet(BuildContext context) {
  final v = context.dc;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: v.surface,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: v.cardBorder),
    ),
    builder: (ctx) => const _GameRulesSheet(),
  );
}

class _GameRulesSheet extends StatelessWidget {
  const _GameRulesSheet();

  static const _rules = [
    'Tap between two dots to draw a line.',
    'Close a box with four sides to claim it and score a point.',
    'Capturing a box gives you another turn immediately.',
    'When all lines are drawn, whoever has the most boxes wins.',
  ];

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
            'HOW TO PLAY',
            style: t.playerName.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapMD,
          for (final rule in _rules) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: v.playerA),
                ),
                AppSpacing.hGapSM,
                Expanded(
                  child: Text(rule, style: t.bodySmall),
                ),
              ],
            ),
            AppSpacing.vGapSM,
          ],
          AppSpacing.vGapMD,
          NeonButton(
            label: 'GOT IT',
            onPressed: () => Navigator.pop(context),
            color: v.playerA,
          ),
          AppSpacing.vGapMD,
        ],
      ),
    );
  }
}
