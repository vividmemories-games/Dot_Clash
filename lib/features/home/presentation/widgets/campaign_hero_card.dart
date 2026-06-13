import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../campaign/domain/campaign_level.dart';
import '../../../campaign/domain/campaign_progress.dart';
import '../../../campaign/domain/campaign_world.dart';
import '../../../campaign/providers/campaign_providers.dart';

class CampaignHeroCard extends ConsumerWidget {
  const CampaignHeroCard({
    super.key,
    required this.campaignLocked,
    required this.lockSubtitle,
    required this.onNeedsLives,
  });

  final bool campaignLocked;
  final String lockSubtitle;
  final VoidCallback onNeedsLives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final progress = ref.watch(campaignProgressProvider);
    final continueLevelAsync = ref.watch(continueLevelProvider);
    final continueId = ref.watch(continueLevelIdProvider);

    return continueLevelAsync.when(
      data: (level) => _HeroCard(
        v: v,
        t: t,
        level: level,
        progress: progress,
        continueId: continueId,
        campaignLocked: campaignLocked,
        lockSubtitle: lockSubtitle,
        onNeedsLives: onNeedsLives,
      ),
      loading: () => _SkeletonCard(v: v),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── World-stage hero card ─────────────────────────────────────────────────────

class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.v,
    required this.t,
    required this.level,
    required this.progress,
    required this.continueId,
    required this.campaignLocked,
    required this.lockSubtitle,
    required this.onNeedsLives,
  });

  final DotClashVisuals v;
  final AppTextStyles t;
  final CampaignLevel? level;
  final CampaignProgress progress;
  final String? continueId;
  final bool campaignLocked;
  final String lockSubtitle;
  final VoidCallback onNeedsLives;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _pan;
  late final Animation<double> _glowOpacity;
  late final Animation<Alignment> _panAlignment;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowOpacity = Tween<double>(begin: 0.3, end: 0.75).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    _pan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _panAlignment = AlignmentTween(
      begin: const Alignment(-0.2, -0.1),
      end: const Alignment(0.2, 0.1),
    ).animate(CurvedAnimation(parent: _pan, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    if (level == null) return _buildCompleted(context);

    final v = widget.v;
    final t = widget.t;
    final progress = widget.progress;

    final world = CampaignCatalog.worldById(level.worldId);
    final totalStars = progress.totalStars;
    final isBoss = level.isBoss;
    final levelStars = progress.starsFor(level.id);

    final accentColor = isBoss ? v.red : v.green;
    final titleColor = isBoss ? v.red : v.playerA;

    return GestureDetector(
      onTap: () => context.go(AppRoutes.campaign),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: AppSpacing.roundedXL,
          border: Border.all(
            color: accentColor.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: v.useGlow
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.14),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.roundedXL,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Background map image with parallax pan
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _panAlignment,
                    builder: (_, __) => Image.asset(
                      'assets/images/card_campaign_hero.png',
                      fit: BoxFit.cover,
                      alignment: _panAlignment.value,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.82),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Decorative ambient orb (top-right)
                if (v.useGlow)
                  Positioned(
                    right: -16,
                    top: -16,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentColor.withOpacity(0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top meta row ──────────────────────────────────────────
                      Row(
                        children: [
                          Icon(Icons.map_outlined, size: 12, color: titleColor),
                          AppSpacing.hGapXS,
                          Text(
                            'CAMPAIGN',
                            style: t.scoreLabel.copyWith(
                              color: titleColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                          AppSpacing.hGapXS,
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: v.textDisabled,
                              shape: BoxShape.circle,
                            ),
                          ),
                          AppSpacing.hGapXS,
                          Expanded(
                            child: Text(
                              'World ${level.worldId}',
                              style: t.scoreLabel.copyWith(
                                color: v.textSecondary,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (totalStars > 0) ...[
                            Icon(Icons.star_rounded, size: 13, color: v.gold),
                            AppSpacing.hGapXS,
                            Text(
                              '$totalStars',
                              style: t.scoreLabel.copyWith(color: v.gold),
                            ),
                          ],
                        ],
                      ),
                      AppSpacing.vGapSM,

                      // ── World identity ────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'WORLD ${level.worldId}',
                              style: t.heroTitle.copyWith(
                                fontSize: 22,
                                color: v.textPrimary,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                          if (isBoss) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: v.red.withOpacity(0.15),
                                borderRadius: AppSpacing.roundedFull,
                                border: Border.all(
                                  color: v.red.withOpacity(0.6),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.whatshot_rounded,
                                      size: 12, color: v.red),
                                  const SizedBox(width: 4),
                                  Text(
                                    'BOSS',
                                    style: t.scoreLabel.copyWith(
                                      color: v.red,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Current level stars
                            Row(
                              children: List.generate(3, (i) {
                                final lit = i < levelStars;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Icon(
                                    lit
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 16,
                                    color: lit ? v.gold : v.textDisabled,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                      AppSpacing.vGapXS,

                      // ── Level progress label ──────────────────────────────────
                      Row(
                        children: [
                          Text(
                            'LEVEL PROGRESS',
                            style: t.scoreLabel,
                          ),
                          const Spacer(),
                          Text(
                            '${level.index} / ${world.levelCount}',
                            style: t.bodySmall.copyWith(
                              color: v.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // ── Map path nodes ────────────────────────────────────────
                      _MapPath(
                        world: world,
                        currentIndex: level.index,
                        progress: progress,
                        accentColor: accentColor,
                        v: v,
                        t: t,
                      ),
                      AppSpacing.vGapSM,

                      // ── Reward preview ────────────────────────────────────────
                      Row(
                        children: [
                          Text(
                            'NEXT REWARD',
                            style: t.scoreLabel,
                          ),
                          AppSpacing.hGapSM,
                          _RewardBadge(
                            icon: Icons.star_rounded,
                            label: '+${level.xpReward} XP',
                            color: v.playerA,
                            v: v,
                            t: t,
                          ),
                          AppSpacing.hGapXS,
                          _RewardBadge(
                            icon: Icons.monetization_on_rounded,
                            label: '+${level.coinReward}',
                            color: v.gold,
                            v: v,
                            t: t,
                          ),
                        ],
                      ),
                      AppSpacing.vGapSM,

                      // ── CONTINUE CTA button ───────────────────────────────────
                      AnimatedBuilder(
                        animation: _glowOpacity,
                        builder: (context, _) {
                          return Container(
                            decoration: v.useGlow
                                ? BoxDecoration(
                                    borderRadius: AppSpacing.roundedMD,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withOpacity(
                                            _glowOpacity.value * 0.45),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  )
                                : null,
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 11),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: AppSpacing.roundedMD,
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  if (widget.campaignLocked) {
                                    widget.onNeedsLives();
                                    return;
                                  }
                                  context.push('/campaign/play/${level.id}');
                                },
                                icon: Icon(
                                  widget.campaignLocked
                                      ? Icons.bolt_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  widget.campaignLocked
                                      ? ('NEED A LIFE')
                                      : ('CONTINUE'),
                                  style: t.playerName.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleted(BuildContext context) {
    final v = widget.v;
    final t = widget.t;
    return GestureDetector(
      onTap: () => context.go(AppRoutes.campaign),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [v.surface, Color.lerp(v.surface, v.gold, 0.06)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppSpacing.roundedXL,
          border: Border.all(color: v.gold.withOpacity(0.6), width: 1.5),
          boxShadow: v.useGlow
              ? [BoxShadow(color: v.gold.withOpacity(0.15), blurRadius: 20)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: v.gold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emoji_events_rounded, color: v.gold, size: 28),
            ),
            AppSpacing.hGapMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAMPAIGN COMPLETE!',
                    style: t.playerName.copyWith(color: v.gold, fontSize: 16),
                  ),
                  AppSpacing.vGapXS,
                  Text(
                    'All worlds conquered. True champion!',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: v.gold),
          ],
        ),
      ),
    );
  }
}

// ── Map path node visualization ───────────────────────────────────────────────

class _MapPath extends StatelessWidget {
  const _MapPath({
    required this.world,
    required this.currentIndex,
    required this.progress,
    required this.accentColor,
    required this.v,
    required this.t,
  });

  final CampaignWorld world;
  final int currentIndex;
  final CampaignProgress progress;
  final Color accentColor;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    const windowSize = 6;
    final start = (currentIndex - 2).clamp(1, world.levelCount);
    final end = (start + windowSize - 1).clamp(1, world.levelCount);

    final nodes = <_NodeData>[];
    for (var i = start; i <= end; i++) {
      final id = CampaignCatalog.levelId(world.id, i);
      nodes.add(_NodeData(
        index: i,
        isCurrent: i == currentIndex,
        isCleared: progress.starsFor(id) >= 1,
        isBoss: world.bossLevelIndexes.contains(i),
      ));
    }

    return Row(
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: nodes[i - 1].isCleared || nodes[i - 1].isCurrent
                    ? accentColor.withOpacity(0.5)
                    : v.cardBorder,
              ),
            ),
          _MapNode(node: nodes[i], accentColor: accentColor, v: v, t: t),
        ],
      ],
    );
  }
}

class _NodeData {
  const _NodeData({
    required this.index,
    required this.isCurrent,
    required this.isCleared,
    required this.isBoss,
  });
  final int index;
  final bool isCurrent;
  final bool isCleared;
  final bool isBoss;
}

class _MapNode extends StatelessWidget {
  const _MapNode({
    required this.node,
    required this.accentColor,
    required this.v,
    required this.t,
  });

  final _NodeData node;
  final Color accentColor;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    final size = node.isCurrent ? 36.0 : 28.0;

    Color bgColor;
    Color borderColor;
    Widget content;

    if (node.isCurrent) {
      bgColor = accentColor.withOpacity(0.2);
      borderColor = accentColor;
      content = Text(
        '${node.index}',
        style: t.playerName.copyWith(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      );
    } else if (node.isBoss) {
      bgColor = v.red.withOpacity(0.12);
      borderColor = v.red.withOpacity(0.7);
      content = Icon(Icons.whatshot_rounded, size: 13, color: v.red);
    } else if (node.isCleared) {
      bgColor = v.gold.withOpacity(0.12);
      borderColor = v.gold.withOpacity(0.6);
      content = Icon(Icons.star_rounded, size: 13, color: v.gold);
    } else {
      bgColor = v.surface;
      borderColor = v.cardBorder;
      content = Text(
        '${node.index}',
        style: t.scoreLabel.copyWith(
          color: v.textDisabled,
          fontSize: 10,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: node.isCurrent ? 2 : 1.5),
        boxShadow: v.useGlow && node.isCurrent
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.35),
                  blurRadius: 10,
                )
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: content,
    );
  }
}

// ── Reward badge ──────────────────────────────────────────────────────────────

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.v,
    required this.t,
  });

  final IconData icon;
  final String label;
  final Color color;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: t.bodySmall.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading ──────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.v});
  final DotClashVisuals v;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedXL,
        border: Border.all(color: v.cardBorder),
      ),
    );
  }
}
