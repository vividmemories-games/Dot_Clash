import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/dot_clash_visuals.dart';
import '../layout/app_spacing.dart';

/// Circular icon button with neon glow ring.
class NeonIconButton extends StatelessWidget {
  const NeonIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 44,
    this.iconSize = 20,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final accent = color ?? v.playerA;

    final btn = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed?.call();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: v.surface,
          shape: BoxShape.circle,
          border: Border.all(color: accent.withOpacity(0.6), width: 1.5),
          boxShadow: v.useGlow
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: accent, size: iconSize),
      ),
    );

    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

/// Small badge + icon combo for action bar buttons (e.g., HINT with count).
class NeonActionButton extends StatelessWidget {
  const NeonActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.badgeCount,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final int? badgeCount;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final base = color ?? v.textPrimary;
    final effectiveColor = enabled ? base : v.textDisabled;

    return Expanded(
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: v.surface,
            borderRadius: AppSpacing.roundedMD,
            border: Border.all(
              color: enabled
                  ? effectiveColor.withOpacity(0.25)
                  : v.cardBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: effectiveColor, size: 24),
                  if (badgeCount != null)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: v.playerB,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: v.scaffold,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$badgeCount',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: v.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.vGapXS,
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
