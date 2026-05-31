import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_card.dart';
import '../domain/campaign_progress.dart';
import '../domain/campaign_world.dart';
import '../providers/campaign_providers.dart';
import '../../home/presentation/widgets/lives_refill_sheet.dart';
import '../../profile/providers/lives_provider.dart';
import '../../profile/providers/profile_providers.dart';
import '../../tutorial/providers/tutorial_provider.dart';
import '../../../services/ads/ad_reward_router.dart';
import 'level_brief_sheet.dart';
import 'widgets/level_node.dart';

class CampaignMapScreen extends ConsumerWidget {
  const CampaignMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final progress = ref.watch(campaignProgressProvider);
    final continueId = ref.watch(continueLevelIdProvider);
    if (kDebugMode) {
      debugPrint(
        '[CampaignMap] build levelsStarred=${progress.starsByLevelId.length} '
        'lastLevel=${progress.lastLevelId}',
      );
    }

    return Scaffold(
      backgroundColor: v.scaffold,
      appBar: AppBar(
        backgroundColor: v.scaffold,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'CAMPAIGN',
          style: t.scoreLabel,
        ),
        actions: [
          if (continueId != null)
            TextButton(
              onPressed: () => _playLevel(context, ref, continueId!),
              child: Text(
                'PLAY',
                style: t.bodySmall.copyWith(color: v.gold),
              ),
            ),
        ],
      ),
      body: ListView.builder(
        padding: AppSpacing.pagePadding,
        itemCount: CampaignCatalog.worlds.length,
        itemBuilder: (context, i) {
          final world = CampaignCatalog.worlds[i];
          return _WorldSection(
            world: world,
            progress: progress,
            ref: ref,
          );
        },
      ),
    );
  }
}

Future<void> _playLevel(
  BuildContext context,
  WidgetRef ref,
  String levelId,
) async {
  final lives = ref.read(livesSnapshotProvider);
  final tutorialFree = ref.read(tutorialFreeAttemptProvider(levelId));
  if (lives.effectiveLives <= 0 && !tutorialFree) {
    final v = context.dc;
    final coins = ref.read(profileProvider).valueOrNull?.coins ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: v.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: v.cardBorder),
      ),
      builder: (_) => LivesRefillSheet(
        snapshot: lives,
        coins: coins,
        onBuyLife: () => ref.read(livesControllerProvider).purchaseLife(),
        onWatchAd: () =>
            ref.read(adRewardRouterProvider).showRewardedLifeAd(),
      ),
    );
    return;
  }
  if (context.mounted) context.push('/campaign/play/$levelId');
}

class _WorldSection extends StatelessWidget {
  const _WorldSection({
    required this.world,
    required this.progress,
    required this.ref,
  });

  final CampaignWorld world;
  final CampaignProgress progress;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final isUnlocked = progress.isWorldUnlocked(world.id);
    final worldStars = progress.starsForWorld(world.id);
    final continueId = progress.continueLevelId;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // World header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WORLD ${world.id}',
                      style: t.bodySmall.copyWith(
                        color: isUnlocked ? v.playerA : v.textDisabled,
                        letterSpacing: 1.2,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      world.title,
                      style: t.playerName.copyWith(
                        color: isUnlocked ? v.textPrimary : v.textDisabled,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      world.subtitle,
                      style: t.bodySmall.copyWith(color: v.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!isUnlocked)
                Icon(Icons.lock_rounded, color: v.textDisabled, size: 20)
              else
                _StarBadge(earned: worldStars, max: world.maxStars, v: v, t: t),
            ],
          ),
          AppSpacing.vGapSM,

          if (!isUnlocked)
            NeonCard(
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: v.textDisabled),
                  AppSpacing.hGapSM,
                  Text(
                    'Complete World ${world.id - 1} to unlock',
                    style: t.bodySmall.copyWith(color: v.textDisabled),
                  ),
                ],
              ),
            )
          else
            _LevelGrid(
              world: world,
              progress: progress,
              continueId: continueId,
              ref: ref,
            ),
        ],
      ),
    );
  }
}

class _LevelGrid extends StatelessWidget {
  const _LevelGrid({
    required this.world,
    required this.progress,
    required this.continueId,
    required this.ref,
  });

  final CampaignWorld world;
  final CampaignProgress progress;
  final String? continueId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final levelsAsync = ref.watch(worldLevelsProvider(world.id));

    return levelsAsync.when(
      data: (levels) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: AppSpacing.xs,
          mainAxisSpacing: AppSpacing.xs,
          childAspectRatio: 0.85,
        ),
        itemCount: levels.length,
        itemBuilder: (context, i) {
          final level = levels[i];
          final stars = progress.starsFor(level.id);
          final isUnlocked = progress.isLevelUnlocked(level.id);
          final isCurrent = level.id == continueId;
          return LevelNode(
            level: level,
            stars: stars,
            isUnlocked: isUnlocked,
            isCurrent: isCurrent,
            onTap: () => _showBrief(context, level),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showBrief(BuildContext context, dynamic level) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LevelBriefSheet(level: level, progress: progress),
    );
  }
}

class _StarBadge extends StatelessWidget {
  const _StarBadge({
    required this.earned,
    required this.max,
    required this.v,
    required this.t,
  });
  final int earned;
  final int max;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 14, color: v.gold),
        AppSpacing.hGapXS,
        Text('$earned/$max', style: t.bodySmall.copyWith(color: v.gold)),
      ],
    );
  }
}
