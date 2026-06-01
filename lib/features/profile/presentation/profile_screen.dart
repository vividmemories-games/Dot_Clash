import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../features/home/presentation/widgets/home_screen_background.dart';
import '../../../features/profile/domain/progression.dart';
import '../../../features/profile/domain/rank.dart';
import '../../../features/profile/providers/lives_provider.dart';
import '../../../features/profile/providers/profile_providers.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/layout/responsive_layout.dart';
import '../../../shared/widgets/profile_avatar_chip.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final profile = ref.watch(profileProvider).valueOrNull;
    final livesSnapshot = ref.watch(livesSnapshotProvider);

    final displayName = profile?.displayName ?? 'Player';
    final avatarId = profile?.avatarId ?? 'avatar_orb_cyan';
    final initialSkinId = profile?.initialSkinId ?? 'initial_skin_classic';
    final rankTier = profile?.rankTier ?? RankTier.bronze;
    final rankLabel = RankSystem.label(rankTier);
    final rankColor = _rankColor(v, rankTier);

    final level = profile?.campaignPlayerLevel ?? 1;
    final totalStars = profile?.totalCampaignStars ?? 0;
    final starProgress = Progression.starsInCurrentPlayerLevel(totalStars);

    final wins = profile?.wins ?? 0;
    final gamesPlayed = profile?.gamesPlayed ?? 0;
    final winStreak = profile?.winStreak ?? 0;
    final bestStreak = profile?.bestWinStreak ?? 0;
    final coins = profile?.coins ?? 0;
    final winRate = gamesPlayed == 0 ? 0 : ((wins / gamesPlayed) * 100).round();

    final content = SafeArea(
      bottom: false,
      child: MaxWidthBox(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Section label ───────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PROFILE',
                  style: context.txt.scoreLabel,
                ),
              ),
              AppSpacing.vGapMD,

              // ── Avatar + name + rank ────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    ProfileAvatarChip(
                      avatarId: avatarId,
                      displayName: displayName,
                      initialSkinId: initialSkinId,
                      size: 88,
                      showInitial: true,
                      showRankAura: true,
                      rankTier: rankTier,
                      onTap: () => context.go(AppRoutes.shop),
                    ),
                    AppSpacing.vGapSM,
                    Text(
                      displayName,
                      style: context.txt.heroTitle.copyWith(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapXS,
                    _RankBadge(
                      label: rankLabel,
                      color: rankColor,
                      v: v,
                      t: context.txt,
                    ),
                  ],
                ),
              ),
              AppSpacing.vGapMD,

              // ── Economy strip ───────────────────────────────────────────
              _EconomyStrip(
                coins: coins,
                livesCount: livesSnapshot.effectiveLives,
                maxLives: Progression.maxLives,
                v: v,
                t: context.txt,
              ),
              AppSpacing.vGapMD,

              // ── Level + star progress ───────────────────────────────────
              _LevelProgressCard(
                level: level,
                starsIntoLevel: starProgress.intoLevel,
                starsForLevel: starProgress.forLevel,
                levelFraction: starProgress.fraction,
                totalStars: totalStars,
                v: v,
                t: context.txt,
              ),
              AppSpacing.vGapMD,

              // ── Stats grid ──────────────────────────────────────────────
              _StatsGrid(
                wins: wins,
                winRate: winRate,
                currentStreak: winStreak,
                bestStreak: bestStreak,
                v: v,
                t: context.txt,
              ),
              AppSpacing.vGapLG,

              // ── Settings button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: v.textPrimary,
                    side: BorderSide(color: v.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.roundedMD,
                    ),
                  ),
                  onPressed: () => context.push(AppRoutes.settings),
                  icon: Icon(Icons.settings_outlined, size: 18, color: v.textSecondary),
                  label: Text(
                    'SETTINGS',
                    style: context.txt.playerName.copyWith(
                      color: v.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: v.scaffold,
      body: HomeScreenBackground(child: content),
    );
  }

  static Color _rankColor(DotClashVisuals v, RankTier tier) => switch (tier) {
        RankTier.bronze => const Color(0xFFCD7F32),
        RankTier.silver => const Color(0xFFC0C0C0),
        RankTier.gold => v.gold,
        RankTier.platinum => const Color(0xFF00D4FF),
        RankTier.diamond => const Color(0xFF9D4DFF),
        RankTier.master => const Color(0xFFFF4C4C),
      };
}

// ── Rank badge ────────────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.label,
    required this.color,
    required this.v,
    required this.t,
  });

  final String label;
  final Color color;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: t.playerName.copyWith(
              color: color,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Economy strip ─────────────────────────────────────────────────────────────

class _EconomyStrip extends StatelessWidget {
  const _EconomyStrip({
    required this.coins,
    required this.livesCount,
    required this.maxLives,
    required this.v,
    required this.t,
  });

  final int coins;
  final int livesCount;
  final int maxLives;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EconomyChip(
            icon: Icons.monetization_on_rounded,
            value: '$coins',
            label: 'COINS',
            color: v.gold,
            v: v,
            t: t,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _EconomyChip(
            icon: Icons.bolt_rounded,
            value: '$livesCount/$maxLives',
            label: 'ENERGY',
            color: livesCount >= maxLives ? v.green : v.playerA,
            v: v,
            t: t,
          ),
        ),
      ],
    );
  }
}

class _EconomyChip extends StatelessWidget {
  const _EconomyChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.v,
    required this.t,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          AppSpacing.hGapSM,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: t.playerName.copyWith(fontSize: 16)),
              Text(label, style: t.scoreLabel.copyWith(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Level progress card ───────────────────────────────────────────────────────

class _LevelProgressCard extends StatelessWidget {
  const _LevelProgressCard({
    required this.level,
    required this.starsIntoLevel,
    required this.starsForLevel,
    required this.levelFraction,
    required this.totalStars,
    required this.v,
    required this.t,
  });

  final int level;
  final int starsIntoLevel;
  final int starsForLevel;
  final double levelFraction;
  final int totalStars;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.cardBorder),
        boxShadow: v.useGlow
            ? [BoxShadow(color: v.playerA.withOpacity(0.07), blurRadius: 14)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CAMPAIGN RANK',
                style: t.scoreLabel,
              ),
              const Spacer(),
              Icon(Icons.star_rounded, size: 13, color: v.gold),
              const SizedBox(width: 3),
              Text(
                '$totalStars',
                style: t.bodySmall.copyWith(color: v.gold, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          AppSpacing.vGapSM,
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: v.playerA.withOpacity(0.15),
                  borderRadius: AppSpacing.roundedMD,
                  border: Border.all(color: v.playerA.withOpacity(0.4)),
                ),
                child: Text(
                  'LVL $level',
                  style: t.playerName.copyWith(color: v.playerA, fontSize: 14),
                ),
              ),
              AppSpacing.hGapSM,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: AppSpacing.roundedFull,
                      child: LinearProgressIndicator(
                        value: levelFraction,
                        minHeight: 8,
                        backgroundColor: v.cardBorder.withOpacity(0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(v.playerA),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$starsIntoLevel / $starsForLevel ★ to next level',
                      style: t.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.wins,
    required this.winRate,
    required this.currentStreak,
    required this.bestStreak,
    required this.v,
    required this.t,
  });

  final int wins;
  final int winRate;
  final int currentStreak;
  final int bestStreak;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATISTICS',
          style: t.scoreLabel,
        ),
        AppSpacing.vGapSM,
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '$wins',
                label: 'WINS',
                icon: Icons.emoji_events_rounded,
                color: v.gold,
                v: v,
                t: t,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                value: '$winRate%',
                label: 'WIN RATE',
                icon: Icons.trending_up_rounded,
                color: v.green,
                v: v,
                t: t,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '$currentStreak',
                label: 'CURRENT STREAK',
                icon: Icons.whatshot_rounded,
                color: v.playerA,
                v: v,
                t: t,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                value: '$bestStreak',
                label: 'BEST STREAK',
                icon: Icons.local_fire_department_rounded,
                color: v.gold,
                v: v,
                t: t,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.v,
    required this.t,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [v.surface, Color.lerp(v.surface, color, 0.06)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: v.useGlow
            ? [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12)]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          AppSpacing.hGapSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: t.playerName.copyWith(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: t.scoreLabel.copyWith(fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

