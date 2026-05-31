import 'package:flutter/material.dart';

import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../domain/campaign_level.dart';

class LevelNode extends StatelessWidget {
  const LevelNode({
    super.key,
    required this.level,
    required this.stars,
    required this.isUnlocked,
    required this.isCurrent,
    required this.onTap,
  });

  final CampaignLevel level;
  final int stars;
  final bool isUnlocked;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    final borderColor = level.isBoss
        ? v.red.withOpacity(isUnlocked ? 0.8 : 0.3)
        : (isCurrent
            ? v.gold.withOpacity(0.9)
            : v.cardBorder.withOpacity(isUnlocked ? 1.0 : 0.4));

    final glowColor = isCurrent
        ? v.gold.withOpacity(0.25)
        : (level.isBoss && isUnlocked ? v.red.withOpacity(0.18) : null);

    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: v.surface,
          borderRadius: AppSpacing.roundedMD,
          border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
          boxShadow: glowColor != null && v.useGlow
              ? [BoxShadow(color: glowColor, blurRadius: 14)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Level number
            Text(
              '${level.index}',
              style: t.playerName.copyWith(
                fontSize: 16,
                color: isUnlocked
                    ? (level.isBoss ? v.red : v.textPrimary)
                    : v.textDisabled,
              ),
            ),
            if (level.isBoss) ...[
              const SizedBox(height: 2),
              Text(
                'BOSS',
                style: t.bodySmall.copyWith(
                  fontSize: 9,
                  color: isUnlocked ? v.red : v.textDisabled,
                  letterSpacing: 1,
                ),
              ),
            ],
            const SizedBox(height: 4),
            // Stars
            if (!isUnlocked)
              Icon(Icons.lock_outline_rounded, size: 14, color: v.textDisabled)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final lit = i < stars;
                  return Icon(
                    lit ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 11,
                    color: lit ? v.gold : v.textDisabled.withOpacity(0.5),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
