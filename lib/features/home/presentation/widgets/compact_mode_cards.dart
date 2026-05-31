import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';

class PlayModeCards extends StatelessWidget {
  const PlayModeCards({
    super.key,
    required this.onAiTap,
    required this.onLocalTap,
  });

  final VoidCallback onAiTap;
  final VoidCallback onLocalTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRACTICE', style: t.scoreLabel),
        AppSpacing.vGapXS,
        Text(
          'Free sandbox — no lives required.',
          style: t.bodySmall,
        ),
        AppSpacing.vGapMD,
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            if (isNarrow) {
              return Column(
                children: [
                  _ModeTile(
                    title: 'Quick Match',
                    subtitle: 'Jump in anytime',
                    icon: Icons.sports_esports_outlined,
                    color: v.playerA,
                    onTap: onAiTap,
                    isLarge: true,
                  ),
                  AppSpacing.vGapSM,
                  _ModeTile(
                    title: 'LOCAL',
                    subtitle: 'Pass and play on this device',
                    icon: Icons.people_outline_rounded,
                    color: v.playerB,
                    onTap: onLocalTap,
                    isLarge: true,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _ModeTile(
                    title: 'Quick Match',
                    subtitle: 'Jump in anytime',
                    icon: Icons.sports_esports_outlined,
                    color: v.playerA,
                    onTap: onAiTap,
                    isLarge: true,
                  ),
                ),
                AppSpacing.hGapSM,
                Expanded(
                  child: _ModeTile(
                    title: 'LOCAL',
                    subtitle: 'Pass and play on this device',
                    icon: Icons.people_outline_rounded,
                    color: v.playerB,
                    onTap: onLocalTap,
                    isLarge: true,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.locked = false,
    this.isLarge = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool locked;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [v.surface, v.surfaceElevated],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppSpacing.roundedLG,
          border: Border.all(color: color.withOpacity(0.45)),
          boxShadow: v.useGlow
              ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 14)]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            AppSpacing.hGapSM,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.playerName.copyWith(
                      color: color,
                      letterSpacing: 1.6,
                      fontSize: isLarge ? 16 : null,
                    ),
                  ),
                  SizedBox(height: isLarge ? AppSpacing.sm : AppSpacing.xs),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ],
              ),
            ),
            Icon(
              locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
              color: color.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}
