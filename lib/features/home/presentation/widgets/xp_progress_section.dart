import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/profile/domain/progression.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/neon_card.dart';

/// Campaign star-based player level (not match XP).
class XpProgressSection extends StatelessWidget {
  const XpProgressSection({
    super.key,
    required this.level,
    required this.totalStars,
  });

  final int level;
  final int totalStars;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final stars = Progression.starsInCurrentPlayerLevel(totalStars);

    return NeonCard(
      glowColor: v.playerA.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('CAMPAIGN RANK', style: t.scoreLabel),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 14, color: v.gold),
                  AppSpacing.hGapXS,
                  Text('$totalStars', style: t.bodySmall.copyWith(color: v.gold)),
                ],
              ),
              AppSpacing.hGapSM,
              Text('LVL $level', style: t.playerName.copyWith(color: v.playerA)),
            ],
          ),
          AppSpacing.vGapSM,
          LinearProgressIndicator(
            value: stars.fraction,
            minHeight: 10,
            borderRadius: AppSpacing.roundedFull,
            backgroundColor: v.cardBorder.withOpacity(0.5),
            valueColor: AlwaysStoppedAnimation<Color>(v.playerA),
          ),
          AppSpacing.vGapXS,
          Text(
            '${stars.intoLevel}/${stars.forLevel} ★ to next player level',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
