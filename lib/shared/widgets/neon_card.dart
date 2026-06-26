import 'package:flutter/material.dart';

import '../../core/theme/dot_clash_visuals.dart';
import '../layout/app_spacing.dart';

/// A card with dark-surface + neon-border + optional glow look.
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.glowColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = AppSpacing.radiusLG,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.glowBlur = 12,
    this.glowSpread = 0,
    this.clipInk = false,
  });

  final Widget child;
  final Color? glowColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double glowBlur;
  final double glowSpread;

  /// When true, clips children to the card radius so [ListTile] / [InkWell]
  /// ripples stay inside the border. Off by default — clipping chops wide
  /// letter-spacing and pill buttons in shop/resources cards.
  final bool clipInk;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final effectiveBorder = borderColor ?? v.cardBorder;
    final effectiveFill = color ?? v.surface;
    final showGlow = v.useGlow && glowColor != null;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder, width: borderWidth),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: glowColor!,
                  blurRadius: glowBlur,
                  spreadRadius: glowSpread,
                ),
              ]
            : null,
      ),
      child: clipInk
          ? Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(borderRadius),
              clipBehavior: Clip.antiAlias,
              child: child,
            )
          : child,
    );
  }
}
