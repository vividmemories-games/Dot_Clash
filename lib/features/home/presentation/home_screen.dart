import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../features/campaign/providers/campaign_providers.dart';
import '../../../features/game/domain/models/ai_preset.dart';
import '../../../features/game/domain/models/game_state.dart';
import '../../../features/game/providers/game_provider.dart';
import '../../../features/home/providers/home_data_providers.dart';
import '../../../features/home/presentation/widgets/campaign_hero_card.dart';
import '../../../features/home/presentation/widgets/home_action_row.dart';
import '../../../features/home/presentation/widgets/daily_missions_section.dart';
import '../../../features/home/presentation/widgets/home_screen_background.dart';
import '../../../features/home/presentation/widgets/home_top_bar.dart';
import '../../../features/home/presentation/widgets/lives_refill_sheet.dart';
import '../../../features/profile/domain/lives_logic.dart';
import '../../../features/profile/providers/lives_provider.dart';
import '../../../features/profile/providers/profile_providers.dart';
import '../../../features/tutorial/providers/tutorial_provider.dart';
import '../../../features/tutorial/presentation/coach_tour_target.dart';
import '../../../features/tutorial/domain/coach_tour_step.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/layout/responsive_layout.dart';
import '../../../shared/widgets/neon_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final livesSnapshot = ref.watch(livesSnapshotProvider);
    final missions = ref.watch(dailyMissionsProvider);
    final continueId = ref.watch(continueLevelIdProvider);
    final tutorialFreeAttempt = continueId != null &&
        ref.watch(tutorialFreeAttemptProvider(continueId));

    final campaignLocked =
        !livesSnapshot.canPlayRanked && !tutorialFreeAttempt;
    final lockSubtitle = _lockSubtitle(livesSnapshot);

    final content = SafeArea(
      child: MaxWidthBox(
        child: Column(
          children: [
            // ── Zone 1: Compact top utility strip ───────────────────────────
            HomeTopBar(
              profile: profile,
              livesSnapshot: livesSnapshot,
              onOpenSettings: () => context.push(AppRoutes.settings),
              onOpenShop: () => context.go(AppRoutes.shop),
              onOpenProfile: () => context.go(AppRoutes.profile),
              onLivesTap: () => _showLivesSheet(
                context: context,
                ref: ref,
                livesSnapshot: livesSnapshot,
                coins: profile?.coins ?? 0,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Zone 2: Hero progress stage (dominant CTA) ───────────
                    CoachTourTarget(
                      id: CoachTourTargetId.homeCampaignHero,
                      child: CampaignHeroCard(
                        campaignLocked: campaignLocked,
                        lockSubtitle: lockSubtitle,
                        onNeedsLives: () => _showLivesSheet(
                          context: context,
                          ref: ref,
                          livesSnapshot: livesSnapshot,
                          coins: profile?.coins ?? 0,
                        ),
                      ),
                    ),
                    AppSpacing.vGapSM,

                    // ── Zone 3: Action row (Quick Match / Daily Puzzle / Local) ─
                    HomeActionRow(
                      onAiTap: () => _startVsAiChallenge(context, ref),
                      onLocalTap: () => _pickLocalBoardSize(context, ref),
                    ),
                    AppSpacing.vGapMD,

                    // ── Zone 4: Daily missions ───────────────────────────────
                    DailyMissionsSection(
                      missions: missions,
                      onClaim: (id) async {
                        final ok = await ref
                            .read(profileRepositoryProvider)
                            .claimDailyMission(id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Mission reward claimed!' : 'Mission not ready yet.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: context.dc.scaffold,
      body: HomeScreenBackground(child: content),
    );
  }

  static String _lockSubtitle(LivesSnapshot livesSnapshot) {
    if (livesSnapshot.timeUntilNextLife == null) {
      return 'No lives. Wait for refill or buy from the shop.';
    }
    return 'No lives. Next life in ${_formatMmSs(livesSnapshot.timeUntilNextLife!)}.';
  }

  Future<void> _showLivesSheet({
    required BuildContext context,
    required WidgetRef ref,
    required LivesSnapshot livesSnapshot,
    required int coins,
  }) async {
    final v = context.dc;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: v.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: v.cardBorder),
      ),
      builder: (_) => LivesRefillSheet(
        onBuyLife: () => ref.read(livesControllerProvider).purchaseLife(),
      ),
    );
  }

  static String _formatMmSs(Duration duration) {
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _pickLocalBoardSize(BuildContext context, WidgetRef ref) async {
    final v = context.dc;
    final size = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: v.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: v.cardBorder),
      ),
      builder: (_) => const _LocalBoardSizePicker(),
    );

    if (size != null && context.mounted) {
      final config = GameConfig(
        mode: GameMode.local,
        rows: size,
        cols: size,
      );
      ref.read(gameConfigProvider.notifier).state = config;
      context.push('/game', extra: config);
    }
  }

  Future<void> _startVsAiChallenge(BuildContext context, WidgetRef ref) async {
    final v = context.dc;
    final preset = AiPreset.random();
    final play = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: v.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: v.cardBorder),
      ),
      builder: (_) => _AiPresetBriefSheet(preset: preset),
    );

    if (play == true && context.mounted) {
      final config = GameConfig.vsAi(preset);
      ref.read(gameConfigProvider.notifier).state = config;
      context.push('/game', extra: config);
    }
  }
}

class _LocalBoardSizePicker extends StatelessWidget {
  const _LocalBoardSizePicker();

  static const _sizes = [3, 4, 5, 6, 7, 8, 9, 10];

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: AppSpacing.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSpacing.vGapSM,
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: v.cardBorder,
                  borderRadius: AppSpacing.roundedFull,
                ),
              ),
              AppSpacing.vGapMD,
              Text(
                'BOARD SIZE',
                style: t.scoreLabel,
              ),
              AppSpacing.vGapSM,
              Text(
                'CHOOSE A GRID FOR PASS-AND-PLAY',
                style: t.bodySmall.copyWith(color: v.textSecondary),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapMD,
              ..._sizes.map(
                (size) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: NeonButton(
                    label: '$size × $size',
                    color: size == 5 ? v.playerA : v.playerB,
                    width: double.infinity,
                    onPressed: () => Navigator.pop(context, size),
                  ),
                ),
              ),
              AppSpacing.vGapMD,
            ],
          ),
        ),
      ),
    );
  }
}

class _AiPresetBriefSheet extends StatelessWidget {
  const _AiPresetBriefSheet({required this.preset});

  final AiPreset preset;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSpacing.vGapSM,
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: v.cardBorder,
              borderRadius: AppSpacing.roundedFull,
            ),
          ),
          AppSpacing.vGapMD,
          Text(
            'QUICK MATCH',
            style: t.scoreLabel,
          ),
          AppSpacing.vGapMD,
          Text(
            preset.name,
            style: t.heroTitle.copyWith(fontSize: 28, color: v.playerA),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapSM,
          Text(
            preset.description,
            style: t.body.copyWith(color: v.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapSM,
          Text(
            '${preset.rows}×${preset.cols} GRID · TOUGH RIVAL',
            style: t.bodySmall,
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapMD,
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: 'PLAY',
              icon: Icons.play_arrow_rounded,
              color: v.playerA,
              height: 58,
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
          AppSpacing.vGapSM,
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: t.bodySmall.copyWith(color: v.textSecondary),
            ),
          ),
          AppSpacing.vGapMD,
        ],
      ),
    );
  }
}
