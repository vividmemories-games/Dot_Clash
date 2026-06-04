import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../features/home/presentation/widgets/lives_refill_sheet.dart';
import '../../../features/profile/domain/lives_logic.dart';
import '../../../features/profile/providers/lives_provider.dart';
import '../../../features/tutorial/providers/tutorial_provider.dart';
import '../../../services/ads/ad_reward_router.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../../shared/widgets/neon_card.dart';
import '../domain/campaign_level.dart';
import '../domain/campaign_progress.dart';
import '../domain/turn_budget_calculator.dart';

class LevelBriefSheet extends ConsumerWidget {
  const LevelBriefSheet({
    super.key,
    required this.level,
    required this.progress,
  });

  final CampaignLevel level;
  final CampaignProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final currentStars = progress.starsFor(level.id);
    final gridLabel = '${level.gridDotsLabel} (${level.gridBoxesLabel} boxes)';
    final turnBudget = TurnBudgetCalculator.budgetFor(level);
    final livesSnapshot = ref.watch(livesSnapshotProvider);
    final tutorialFree = ref.watch(tutorialFreeAttemptProvider(level.id));
    final powerUpRewards = level.powerUpRewards.isNotEmpty
        ? level.powerUpRewards
        : CampaignLevel.defaultBossPowerUpRewards(level);

    return Container(
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: v.cardBorder),
      ),
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Row(
            children: [
              if (level.isBoss)
                Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: v.red.withOpacity(0.15),
                    borderRadius: AppSpacing.roundedFull,
                    border: Border.all(color: v.red.withOpacity(0.5)),
                  ),
                  child: Text(
                    'BOSS',
                    style: t.bodySmall.copyWith(color: v.red, fontSize: 10),
                  ),
                ),
              Expanded(
                child: Text(
                  level.title,
                  style: t.playerName.copyWith(fontSize: 18),
                ),
              ),
              Row(
                children: List.generate(3, (i) {
                  final lit = i < currentStars;
                  return Icon(
                    lit ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 20,
                    color: lit ? v.gold : v.textDisabled,
                  );
                }),
              ),
            ],
          ),
          AppSpacing.vGapXS,
          Text(
            gridLabel,
            style: t.bodySmall.copyWith(color: v.textSecondary),
          ),
          if (turnBudget != null) ...[
            AppSpacing.vGapXS,
            Row(
              children: [
                Icon(Icons.hourglass_bottom_rounded,
                    size: 14, color: v.playerA),
                AppSpacing.hGapXS,
                Text(
                  'Turn budget: $turnBudget turns',
                  style: t.bodySmall.copyWith(color: v.playerA),
                ),
              ],
            ),
          ],
          AppSpacing.vGapMD,
          NeonCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OBJECTIVES',
                  style: t.bodySmall.copyWith(
                    color: v.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                AppSpacing.vGapXS,
                _ObjectiveTile(star: 1, obj: level.star1, v: v, t: t),
                _ObjectiveTile(star: 2, obj: level.star2, v: v, t: t),
                _ObjectiveTile(star: 3, obj: level.star3, v: v, t: t),
              ],
            ),
          ),
          AppSpacing.vGapSM,
          Row(
            children: [
              Icon(Icons.monetization_on_rounded, size: 14, color: v.gold),
              AppSpacing.hGapXS,
              Text('${level.coinReward} coins', style: t.bodySmall),
              AppSpacing.hGapMD,
              Icon(Icons.workspace_premium_rounded, size: 14, color: v.playerA),
              AppSpacing.hGapXS,
              Text('${level.xpReward} XP', style: t.bodySmall),
            ],
          ),
          if (powerUpRewards.isNotEmpty) ...[
            AppSpacing.vGapXS,
            Text(
              'Win rewards: ${powerUpRewards.entries.map((e) => '+${e.value} ${e.key}').join(' · ')}',
              style: t.bodySmall.copyWith(color: v.gold),
            ),
          ],
          AppSpacing.vGapLG,
          NeonButton(
            label: livesSnapshot.effectiveLives <= 0 && !tutorialFree
                ? ('GET A LIFE')
                : ('PLAY'),
            color: level.isBoss ? v.red : v.green,
            width: double.infinity,
            onPressed: () => _onPlay(context, ref, livesSnapshot),
          ),
          AppSpacing.vGapSM,
        ],
      ),
    );
  }

  Future<void> _onPlay(
    BuildContext context,
    WidgetRef ref,
    LivesSnapshot livesSnapshot,
  ) async {
    final v = context.dc;

    final tutorialFree = ref.read(tutorialFreeAttemptProvider(level.id));
    if (livesSnapshot.effectiveLives <= 0 && !tutorialFree) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: v.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: v.cardBorder),
        ),
        builder: (_) => LivesRefillSheet(
          onBuyLife: () => ref.read(livesControllerProvider).purchaseLife(),
          onWatchAd: () =>
              ref.read(adRewardRouterProvider).showRewardedLifeAd(),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context);
    context.push('/campaign/play/${level.id}');
  }
}

class _ObjectiveTile extends StatelessWidget {
  const _ObjectiveTile({
    required this.star,
    required this.obj,
    required this.v,
    required this.t,
  });
  final int star;
  final StarObjective obj;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.star_rounded, size: 14, color: v.gold),
          Text('$star', style: t.bodySmall.copyWith(color: v.gold)),
          AppSpacing.hGapSM,
          Expanded(child: Text(obj.description, style: t.bodySmall)),
        ],
      ),
    );
  }
}
