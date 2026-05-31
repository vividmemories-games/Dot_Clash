import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/feedback/app_haptics.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';

/// Full-screen tutorial gate — matches boss intro visual language.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.title,
    required this.body,
    required this.onContinue,
    this.onSkip,
    this.showSkip = false,
    this.continueLabel = 'GOT IT',
  });

  final String? title;
  final String body;
  final VoidCallback onContinue;
  final VoidCallback? onSkip;
  final bool showSkip;
  final String continueLabel;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _continue() {
    AppHaptics.lightImpact();
    widget.onContinue();
  }

  void _skip() {
    AppHaptics.lightImpact();
    widget.onSkip?.call();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Material(
      color: Colors.black.withOpacity(0.72),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                children: [
                  if (widget.showSkip)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _skip,
                        child: Text(
                          'SKIP TUTORIAL',
                          style: t.scoreLabel.copyWith(
                            color: v.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                  const Spacer(flex: 2),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: v.playerA.withOpacity(0.12),
                      border: Border.all(
                        color: v.playerA.withOpacity(0.55),
                        width: 1.5,
                      ),
                      boxShadow: v.useGlow
                          ? [
                              BoxShadow(
                                color: v.playerA.withOpacity(0.35),
                                blurRadius: 20,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.touch_app_rounded,
                      color: v.playerA,
                      size: 34,
                    ),
                  ),
                  AppSpacing.vGapMD,
                  Text(
                    'TUTORIAL',
                    style: t.bodySmall.copyWith(
                      color: v.playerA,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  AppSpacing.vGapSM,
                  if (widget.title != null) ...[
                    Text(
                      widget.title!.toUpperCase(),
                      style: t.heroTitle.copyWith(
                        fontSize: 26,
                        color: v.textPrimary,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapSM,
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppSpacing.roundedLG,
                      border: Border.all(color: v.cardBorder),
                      color: v.surface.withOpacity(0.92),
                    ),
                    child: Text(
                      widget.body,
                      style: t.playerName.copyWith(
                        fontSize: 16,
                        height: 1.45,
                        color: v.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(flex: 3),
                  NeonButton(
                    label: widget.continueLabel,
                    color: v.playerA,
                    width: double.infinity,
                    onPressed: _continue,
                  ),
                  AppSpacing.vGapMD,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
