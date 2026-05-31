import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../domain/models/game_state.dart';
import 'boss_persona_theme.dart';
import 'boss_portrait_backdrop.dart';

/// Slim in-match reminder after the cinematic intro — taunt only, no duplicate titles.
class BossTauntChip extends StatelessWidget {
  const BossTauntChip({
    super.key,
    required this.persona,
  });

  final BossPersona persona;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final theme = bossPersonaTheme(persona, v);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.accent.withOpacity(0.10),
          borderRadius: AppSpacing.roundedMD,
          border: Border.all(color: theme.accent.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            Icon(theme.icon, color: theme.accent, size: 18),
            AppSpacing.hGapSM,
            Expanded(
              child: Text(
                theme.taunt,
                style: t.bodySmall.copyWith(
                  color: v.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Persona portrait + tint behind boss matches.
class BossArenaBackground extends StatelessWidget {
  const BossArenaBackground({
    super.key,
    required this.child,
    this.persona,
    this.personaAccent,
  });

  final Widget child;
  final BossPersona? persona;
  final Color? personaAccent;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final theme = persona != null ? bossPersonaTheme(persona!, v) : null;

    if (theme == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: v.scaffold),
          child,
        ],
      );
    }

    return BossPortraitBackdrop.gameplay(
      portraitAsset: theme.portraitAsset,
      v: v,
      fallbackAccent: theme.accent,
      fallbackIcon: theme.icon,
      child: child,
    );
  }
}
