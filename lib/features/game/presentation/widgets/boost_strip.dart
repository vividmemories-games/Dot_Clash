import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/feedback/app_haptics.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../powerups/domain/power_up.dart';
import '../../../powerups/domain/power_up_catalog.dart';
import '../../../tutorial/domain/coach_tour_step.dart';
import '../../../tutorial/presentation/coach_tour_target.dart';
import '../../domain/models/match_session.dart';

typedef BoostTap = Future<void> Function(PowerUpType type);

/// Mock-style power-ups: header, Hold + Riposte cards, gradient Hint CTA.
class PowerUpPanel extends StatelessWidget {
  const PowerUpPanel({
    super.key,
    required this.session,
    required this.inventory,
    required this.enabled,
    required this.onBoostTap,
    required this.onHint,
    required this.hintsLeft,
    this.hintEnabled = true,
  });

  final MatchSession session;
  final Map<String, int> inventory;
  final bool enabled;
  final BoostTap onBoostTap;
  final VoidCallback onHint;
  final int hintsLeft;
  final bool hintEnabled;

  static const _cardTypes = [PowerUpType.hold, PowerUpType.riposte];

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: v.gold),
              AppSpacing.hGapXS,
              Text(
                'POWER-UPS',
                style: t.scoreLabel.copyWith(
                  fontSize: 10,
                  color: v.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(Icons.info_outline_rounded,
                    size: 16, color: v.textSecondary),
                onPressed: () => _showPowerUpInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: _cardTypes.map((type) {
              final used = _isUsed(type);
              final count = inventory[type.id] ?? 0;
              final isRiposte = type == PowerUpType.riposte;
              final canUse = !used &&
                  count > 0 &&
                  (isRiposte
                      ? enabled || session.pendingRiposteOffer
                      : enabled);
              final ripostePrompt = isRiposte &&
                  session.pendingRiposteOffer &&
                  count > 0 &&
                  !used;

              final card = _PowerUpCard(
                title: PowerUpCatalog.labels[type] ?? type.id,
                icon: _iconFor(type),
                count: count,
                color: PowerUpCatalog.accentFor(type, v),
                enabled: canUse,
                used: used,
                highlighted: ripostePrompt,
                onTap: canUse
                    ? () async {
                        AppHaptics.lightImpact();
                        await onBoostTap(type);
                      }
                    : null,
              );

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: type == PowerUpType.hold ? 0 : 4,
                    right: type == PowerUpType.riposte ? 0 : 4,
                  ),
                  child: type == PowerUpType.hold
                      ? CoachTourTarget(
                          id: CoachTourTargetId.gamePowerUpHold,
                          child: card,
                        )
                      : card,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          CoachTourTarget(
            id: CoachTourTargetId.gameHintButton,
            child: _HintGradientButton(
              hintsLeft: hintsLeft,
              enabled: hintEnabled && hintsLeft > 0,
              onTap: onHint,
            ),
          ),
        ],
      ),
    );
  }

  bool _isUsed(PowerUpType type) => switch (type) {
        PowerUpType.hold => session.holdUsed,
        PowerUpType.riposte => session.riposteUsed,
        _ => session.powerUpsUsed.contains(type),
      };

  IconData _iconFor(PowerUpType type) => switch (type) {
        PowerUpType.hold => Icons.pause_circle_outline_rounded,
        PowerUpType.riposte => Icons.replay_rounded,
        PowerUpType.extraTurns => Icons.add_circle_outline_rounded,
        _ => Icons.bolt_rounded,
      };

  void _showPowerUpInfo(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: v.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: v.cardBorder),
      ),
      builder: (ctx) => Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Power-ups', style: t.playerName.copyWith(fontSize: 18)),
            AppSpacing.vGapMD,
            for (final type in [
              PowerUpType.hold,
              PowerUpType.riposte,
              PowerUpType.extraTurns,
            ]) ...[
              Text(
                PowerUpCatalog.labels[type] ?? type.id,
                style: t.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: PowerUpCatalog.accentFor(type, v),
                ),
              ),
              Text(
                PowerUpCatalog.descriptions[type] ?? '',
                style: t.bodySmall,
              ),
              AppSpacing.vGapSM,
            ],
            AppSpacing.vGapMD,
          ],
        ),
      ),
    );
  }
}

class _PowerUpCard extends StatelessWidget {
  const _PowerUpCard({
    required this.title,
    required this.icon,
    required this.count,
    required this.color,
    required this.enabled,
    required this.used,
    this.highlighted = false,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final int count;
  final Color color;
  final bool enabled;
  final bool used;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final opacity = enabled ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: highlighted ? color.withValues(alpha: 0.1) : v.surface,
        borderRadius: AppSpacing.roundedMD,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.roundedMD,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: AppSpacing.roundedMD,
              border: Border.all(
                color: used
                    ? v.textDisabled
                    : highlighted
                        ? color
                        : color.withValues(alpha: enabled ? 0.4 : 0.2),
                width: highlighted ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 18, color: used ? v.textDisabled : color),
                    if (count > 0 && !used)
                      Positioned(
                        right: -10,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: t.bodySmall.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  used ? 'Used' : title,
                  style: t.bodySmall.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: used ? v.textDisabled : v.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient Hint CTA — also used standalone in local mode.
class HintGradientButton extends StatelessWidget {
  const HintGradientButton({
    super.key,
    required this.hintsLeft,
    required this.enabled,
    required this.onTap,
  });

  final int hintsLeft;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: _HintGradientButton(
        hintsLeft: hintsLeft,
        enabled: enabled,
        onTap: onTap,
      ),
    );
  }
}

class _HintGradientButton extends StatelessWidget {
  const _HintGradientButton({
    required this.hintsLeft,
    required this.enabled,
    required this.onTap,
  });

  final int hintsLeft;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final gradient = LinearGradient(
      colors: [v.playerA, v.playerB],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  AppHaptics.lightImpact();
                  onTap();
                }
              : null,
          borderRadius: AppSpacing.roundedFull,
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradient,
              color: null,
              borderRadius: AppSpacing.roundedFull,
              border: Border.all(
                color: Colors.transparent,
              ),
              boxShadow: enabled && v.useGlow
                  ? [
                      BoxShadow(
                        color: v.playerA.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                AppSpacing.hGapSM,
                Text(
                  'HINT',
                  style: t.buttonLabel.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                AppSpacing.hGapSM,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: AppSpacing.roundedFull,
                  ),
                  child: Text(
                    '$hintsLeft',
                    style: t.buttonLabel.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legacy export — [PowerUpPanel] replaces the old 3-chip row.
typedef BoostStrip = PowerUpPanel;
