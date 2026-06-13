import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../home/domain/home_ui_models.dart';
import '../../domain/head_to_head_stats.dart';

Color _outcomeColor(DotClashVisuals v, MatchOutcome outcome) {
  return switch (outcome) {
    MatchOutcome.win => v.green,
    MatchOutcome.loss => v.red,
    MatchOutcome.tie => v.gold,
  };
}

String _outcomeLabel(MatchOutcome outcome) {
  return switch (outcome) {
    MatchOutcome.win => 'WIN',
    MatchOutcome.loss => 'LOSS',
    MatchOutcome.tie => 'TIE',
  };
}

String relativePlayedAt(DateTime playedAt) {
  final diff = DateTime.now().difference(playedAt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${playedAt.month}/${playedAt.day}/${playedAt.year}';
}

/// Small WIN / LOSS / TIE pill on neutral dark cards.
class OutcomeChip extends StatelessWidget {
  const OutcomeChip({super.key, required this.outcome});

  final MatchOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final accent = _outcomeColor(v, outcome);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        _outcomeLabel(outcome),
        style: t.scoreLabel.copyWith(color: accent, fontSize: 9),
      ),
    );
  }
}

class ChallengeHistoryTabBar extends StatefulWidget {
  const ChallengeHistoryTabBar({super.key, required this.labels});

  final List<String> labels;

  @override
  State<ChallengeHistoryTabBar> createState() => _ChallengeHistoryTabBarState();
}

class _ChallengeHistoryTabBarState extends State<ChallengeHistoryTabBar> {
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.of(context);
    if (_controller != next) {
      _controller?.removeListener(_onTabChanged);
      _controller = next;
      _controller?.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final controller = _controller!;
    final selected = controller.index;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: List.generate(widget.labels.length, (i) {
          final isSelected = selected == i;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 4,
                right: i == widget.labels.length - 1 ? 0 : 4,
              ),
              child: _HistoryTabPill(
                label: widget.labels[i],
                isSelected: isSelected,
                onTap: () => controller.animateTo(i),
                visuals: v,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HistoryTabPill extends StatelessWidget {
  const _HistoryTabPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.visuals,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final DotClashVisuals visuals;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final v = visuals;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppSpacing.roundedFull,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? v.gold.withValues(alpha: 0.15)
                : v.surface.withValues(alpha: 0.6),
            borderRadius: AppSpacing.roundedFull,
            border: Border.all(
              color: isSelected
                  ? v.gold.withValues(alpha: 0.9)
                  : v.cardBorder,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: t.scoreLabel.copyWith(
              fontSize: 10,
              color: isSelected ? v.gold : v.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact rival card for Profile preview.
class RivalSummaryCard extends StatelessWidget {
  const RivalSummaryCard({
    super.key,
    required this.rival,
    required this.busy,
    required this.enabled,
    this.onRechallenge,
  });

  final ChallengeRival rival;
  final bool busy;
  final bool enabled;
  final VoidCallback? onRechallenge;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rival.displayName,
                  style: t.playerName.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Series ${rival.record.display}',
                style: t.bodySmall.copyWith(
                  fontSize: 11,
                  color: v.textSecondary,
                ),
              ),
            ],
          ),
          AppSpacing.vGapXS,
          Text(
            relativePlayedAt(rival.lastPlayedAt),
            style: t.bodySmall.copyWith(fontSize: 10, color: v.textSecondary),
          ),
          AppSpacing.vGapSM,
          Row(
            children: [
              ...rival.recentResults.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: OutcomeChip(outcome: m.outcome),
                ),
              ),
              const Spacer(),
              if (onRechallenge != null)
                _RechallengeButton(
                  label: rival.rechallengeLabel,
                  busy: busy,
                  enabled: enabled,
                  onTap: onRechallenge,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full rival row for Challenge History → Rivals tab.
class RivalListTile extends StatelessWidget {
  const RivalListTile({
    super.key,
    required this.rival,
    required this.busy,
    required this.enabled,
    this.onRechallenge,
  });

  final ChallengeRival rival;
  final bool busy;
  final bool enabled;
  final VoidCallback? onRechallenge;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rival.displayName,
                  style: t.playerName.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Series ${rival.record.display}',
                style: t.bodySmall.copyWith(
                  fontSize: 11,
                  color: v.textSecondary,
                ),
              ),
            ],
          ),
          AppSpacing.vGapXS,
          Row(
            children: [
              OutcomeChip(outcome: rival.lastOutcome),
              AppSpacing.hGapSM,
              Text(
                relativePlayedAt(rival.lastPlayedAt),
                style: t.bodySmall.copyWith(
                  fontSize: 10,
                  color: v.textSecondary,
                ),
              ),
              AppSpacing.hGapSM,
              Text(
                '• ${rival.streakLabel}',
                style: t.bodySmall.copyWith(
                  fontSize: 10,
                  color: v.textSecondary,
                ),
              ),
            ],
          ),
          if (onRechallenge != null) ...[
            AppSpacing.vGapSM,
            Align(
              alignment: Alignment.centerRight,
              child: _RechallengeButton(
                label: rival.rechallengeLabel,
                busy: busy,
                enabled: enabled,
                onTap: onRechallenge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chronological match row for Challenge History → History tab.
class MatchHistoryTile extends StatelessWidget {
  const MatchHistoryTile({super.key, required this.match});

  final RecentMatch match;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${match.opponentLabel}',
                  style: t.playerName.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  relativePlayedAt(match.playedAt),
                  style: t.bodySmall.copyWith(
                    fontSize: 10,
                    color: v.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutcomeChip(outcome: match.outcome),
        ],
      ),
    );
  }
}

/// Shown on Challenge home when the player has no head-to-head history yet.
class ChallengeRivalriesEmptyCard extends StatelessWidget {
  const ChallengeRivalriesEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: v.surface.withValues(alpha: 0.72),
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No rivalries yet',
            style: t.playerName.copyWith(fontSize: 15),
          ),
          AppSpacing.vGapXS,
          Text(
            'Remember this game from class? Tap Create above or join with a code.',
            style: t.bodySmall.copyWith(color: v.textSecondary),
          ),
        ],
      ),
    );
  }
}

class ChallengeHistoryEmptyState extends StatelessWidget {
  const ChallengeHistoryEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.cardBorder),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: t.bodySmall.copyWith(color: v.textSecondary),
      ),
    );
  }
}

class _RechallengeButton extends StatelessWidget {
  const _RechallengeButton({
    required this.label,
    required this.busy,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    if (busy) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: v.gold),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppSpacing.roundedFull,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: v.gold.withValues(alpha: 0.12),
            borderRadius: AppSpacing.roundedFull,
            border: Border.all(color: v.gold.withValues(alpha: 0.45)),
          ),
          child: Text(
            label,
            style: t.scoreLabel.copyWith(color: v.gold, fontSize: 9),
          ),
        ),
      ),
    );
  }
}
