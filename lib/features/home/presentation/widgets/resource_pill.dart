import 'package:flutter/material.dart';

import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';

class ResourcePill extends StatelessWidget {
  const ResourcePill({
    super.key,
    required this.icon,
    required this.label,
    required this.iconColor,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(color: iconColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          AppSpacing.hGapXS,
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: v.textPrimary,
              fontSize: 13,
            ),
          ),
          if (trailing != null) ...[
            AppSpacing.hGapXS,
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppSpacing.roundedFull,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
