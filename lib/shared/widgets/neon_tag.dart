import 'package:flutter/material.dart';

import '../../core/theme/dot_clash_visuals.dart';
import '../layout/app_spacing.dart';

/// Small pill-shaped tag, e.g. "TARGET: 12 BOXES" or "RANK: GOLD".
class NeonTag extends StatelessWidget {
  const NeonTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.backgroundColor,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final fg = color ?? v.textSecondary;
    final bg = backgroundColor ?? v.surface;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 13),
            AppSpacing.hGapXS,
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
