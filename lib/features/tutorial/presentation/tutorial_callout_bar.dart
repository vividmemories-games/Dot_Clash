import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/feedback/app_haptics.dart';
import '../../../shared/layout/app_spacing.dart';

/// Compact non-blocking tutorial banner at the bottom of the game screen.
class TutorialCalloutBar extends StatelessWidget {
  const TutorialCalloutBar({
    super.key,
    required this.title,
    required this.body,
    this.onDismiss,
    this.onSkip,
    this.showSkip = false,
    this.showDismiss = true,
  });

  final String? title;
  final String body;
  final VoidCallback? onDismiss;
  final VoidCallback? onSkip;
  final bool showSkip;
  final bool showDismiss;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: v.surface.withOpacity(0.96),
              borderRadius: AppSpacing.roundedLG,
              border: Border.all(color: v.playerA.withOpacity(0.45)),
              boxShadow: v.useGlow
                  ? [
                      BoxShadow(
                        color: v.playerA.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_outlined, size: 16, color: v.playerA),
                      AppSpacing.hGapXS,
                      Text(
                        'TUTORIAL',
                        style: t.scoreLabel.copyWith(
                          color: v.playerA,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      if (showSkip)
                        TextButton(
                          onPressed: () {
                            AppHaptics.lightImpact();
                            onSkip?.call();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'SKIP',
                            style: t.scoreLabel.copyWith(
                              color: v.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (title != null) ...[
                    AppSpacing.vGapXS,
                    Text(
                      title!,
                      style: t.playerName.copyWith(fontSize: 15),
                    ),
                  ],
                  AppSpacing.vGapXS,
                  Text(
                    body,
                    style: t.bodySmall.copyWith(height: 1.35),
                  ),
                  if (showDismiss && onDismiss != null) ...[
                    AppSpacing.vGapSM,
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          AppHaptics.lightImpact();
                          onDismiss!();
                        },
                        child: Text(
                          'GOT IT',
                          style: t.playerName.copyWith(
                            color: v.playerA,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Highlights the score strip during tutorial steps.
class TutorialScoreStripHighlight extends StatelessWidget {
  const TutorialScoreStripHighlight({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppSpacing.roundedMD,
        border: Border.all(color: v.playerA.withOpacity(0.65), width: 1.5),
        boxShadow: v.useGlow
            ? [
                BoxShadow(
                  color: v.playerA.withOpacity(0.25),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
