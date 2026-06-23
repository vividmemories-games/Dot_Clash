import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/profile/providers/lives_provider.dart';
import '../../../features/tutorial/providers/coach_tour_provider.dart';
import '../../../services/ads/ad_reward_router.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../../shared/widgets/neon_card.dart';
import '../domain/campaign_level.dart';
import '../domain/campaign_world.dart';
import 'campaign_play_navigation.dart';
import 'campaign_save_status.dart';

class LevelResultScreen extends ConsumerWidget {
  const LevelResultScreen({
    super.key,
    required this.level,
    required this.starsEarned,
    required this.objectivesMet,
    required this.humanWon,
    this.saveStatus = CampaignSaveStatus.saved,
    this.onRetrySave,
  });

  final CampaignLevel level;
  final int starsEarned;
  final List<bool> objectivesMet;
  final bool humanWon;
  final CampaignSaveStatus saveStatus;
  final Future<void> Function()? onRetrySave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.dc.scaffold,
      body: SafeArea(
        child: LevelResultPanel(
          level: level,
          starsEarned: starsEarned,
          objectivesMet: objectivesMet,
          humanWon: humanWon,
          saveStatus: saveStatus,
          onRetrySave: onRetrySave,
        ),
      ),
    );
  }
}

/// Result summary + navigation actions (used after celebration or standalone).
class LevelResultPanel extends ConsumerWidget {
  const LevelResultPanel({
    super.key,
    required this.level,
    required this.starsEarned,
    required this.objectivesMet,
    required this.humanWon,
    this.saveStatus = CampaignSaveStatus.saved,
    this.onRetrySave,
    this.onLeaveToPlayLevel,
  });

  final CampaignLevel level;
  final int starsEarned;
  final List<bool> objectivesMet;
  final bool humanWon;
  final CampaignSaveStatus saveStatus;
  final Future<void> Function()? onRetrySave;

  /// When set, parent shows a loading overlay before route swap (victory screen).
  final Future<void> Function(String levelId, {required bool replay})?
      onLeaveToPlayLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final nextId = _nextLevelId(level);
    final saveReady = saveStatus == CampaignSaveStatus.saved;
    final saveFailed = saveStatus == CampaignSaveStatus.failed;

    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            humanWon ? 'VICTORY' : 'DEFEAT',
            style: t.scoreLabel.copyWith(
              color: humanWon ? v.green : v.red,
              fontSize: 28,
            ),
          ),
          AppSpacing.vGapMD,
          Text(
            level.title,
            style: t.playerName.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapLG,
          _StarRow(objectivesMet: objectivesMet, v: v),
          AppSpacing.vGapLG,
          if (humanWon) ...[
            NeonCard(
              glowColor: v.gold.withValues(alpha: 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ObjectiveLine(
                    obj: level.star1,
                    achieved: objectivesMet[0],
                    v: v,
                    t: t,
                  ),
                  AppSpacing.vGapXS,
                  _ObjectiveLine(
                    obj: level.star2,
                    achieved: objectivesMet[1],
                    v: v,
                    t: t,
                  ),
                  AppSpacing.vGapXS,
                  _ObjectiveLine(
                    obj: level.star3,
                    achieved: objectivesMet[2],
                    v: v,
                    t: t,
                  ),
                ],
              ),
            ),
            AppSpacing.vGapSM,
            Text(
              '+${level.coinReward} coins  ·  +${level.xpReward} XP',
              style: t.bodySmall.copyWith(color: v.gold),
            ),
            AppSpacing.vGapLG,
          ],
          if (saveFailed) ...[
            NeonCard(
              glowColor: v.red.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: v.red, size: 20),
                  AppSpacing.hGapSM,
                  Expanded(
                    child: Text(
                      'Progress could not sync. Retry before starting the next level.',
                      style: t.bodySmall.copyWith(color: v.red),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetrySave,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            AppSpacing.vGapMD,
          ],
          if (humanWon && nextId != null)
            NeonButton(
              label: saveReady ? 'NEXT LEVEL' : 'NEXT LEVEL (syncing…)',
              color: v.green,
              width: double.infinity,
              onPressed: saveReady
                  ? () => _leaveToPlayLevel(context, nextId, replay: false)
                  : null,
            ),
          AppSpacing.vGapSM,
          NeonButton(
            label: 'CAMPAIGN MAP',
            color: v.playerA,
            width: double.infinity,
            onPressed: () => CampaignPlayNavigation.exitToMap(context),
          ),
          AppSpacing.vGapSM,
          if (!humanWon)
            NeonButton(
              label: 'WATCH AD · RETRY',
              color: v.gold,
              width: double.infinity,
              onPressed: () async {
                final ok =
                    await ref.read(adRewardRouterProvider).showRewardedRetry();
                if (!context.mounted) return;
                AppSnackBar.show(
                  context,
                  ok ? 'Life refunded — try again!' : 'Retry ad unavailable.',
                );
                if (ok) {
                  await _leaveToPlayLevel(context, level.id, replay: true);
                }
              },
            ),
          if (!humanWon) AppSpacing.vGapSM,
          NeonButton(
            label: 'TRY AGAIN',
            color: v.red,
            width: double.infinity,
            onPressed: () => _tryReplayLevel(context, ref, level),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveToPlayLevel(
    BuildContext context,
    String levelId, {
    required bool replay,
  }) async {
    if (onLeaveToPlayLevel != null) {
      await onLeaveToPlayLevel!(levelId, replay: replay);
      return;
    }
    if (replay) {
      await CampaignPlayNavigation.exitToReplayLevel(context, levelId);
    } else {
      await CampaignPlayNavigation.exitToNextLevel(context, levelId);
    }
  }

  void _tryReplayLevel(
    BuildContext context,
    WidgetRef ref,
    CampaignLevel level,
  ) {
    final tutorialFree = ref.read(tutorialFreeAttemptProvider(level.id));
    final lives = ref.read(livesSnapshotProvider);
    if (lives.effectiveLives <= 0 && !tutorialFree) {
      AppSnackBar.show(context, 'No lives left. Wait for refill or buy one.');
      return;
    }
    _leaveToPlayLevel(context, level.id, replay: true);
  }

  static String? _nextLevelId(CampaignLevel level) {
    final parts = CampaignCatalog.parseLevelId(level.id);
    if (parts == null) return null;
    final (worldId, index) = parts;
    final world = CampaignCatalog.worldById(worldId);
    if (index < world.levelCount) {
      return CampaignCatalog.levelId(worldId, index + 1);
    }
    if (worldId < CampaignCatalog.worlds.length) {
      return CampaignCatalog.levelId(worldId + 1, 1);
    }
    return null;
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.objectivesMet, required this.v});
  final List<bool> objectivesMet;
  final DotClashVisuals v;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final lit = i < objectivesMet.length && objectivesMet[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            lit ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 52,
            color: lit ? v.gold : v.textDisabled,
          ),
        );
      }),
    );
  }
}

class _ObjectiveLine extends StatelessWidget {
  const _ObjectiveLine({
    required this.obj,
    required this.achieved,
    required this.v,
    required this.t,
  });
  final StarObjective obj;
  final bool achieved;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          achieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: achieved ? v.green : v.textDisabled,
          size: 18,
        ),
        AppSpacing.hGapSM,
        Expanded(
          child: Text(
            obj.description,
            style: t.bodySmall.copyWith(
              color: achieved ? v.textPrimary : v.textDisabled,
            ),
          ),
        ),
      ],
    );
  }
}
