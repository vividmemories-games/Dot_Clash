import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/feedback/app_haptics.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../../domain/models/game_state.dart';
import 'boss_persona_theme.dart';
import 'boss_portrait_backdrop.dart';

/// Full-screen cinematic taunt shown once when a boss match begins.
class BossIntroOverlay extends StatefulWidget {
  const BossIntroOverlay({
    super.key,
    required this.bossName,
    required this.persona,
    required this.onBegin,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.isMiniBoss = false,
  });

  final String bossName;
  final BossPersona persona;
  final VoidCallback onBegin;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool isMiniBoss;

  @override
  State<BossIntroOverlay> createState() => _BossIntroOverlayState();
}

class _BossIntroOverlayState extends State<BossIntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _portraitScale;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _portraitScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic),
    );
    _enter.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      playBossIntroSting(
        soundEnabled: widget.soundEnabled,
        hapticsEnabled: widget.hapticsEnabled,
      );
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _begin() {
    AppHaptics.lightImpact();
    widget.onBegin();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final theme = bossPersonaTheme(widget.persona, v);

    return Material(
      color: Colors.transparent,
      child: BossPortraitBackdrop.intro(
        portraitAsset: theme.portraitAsset,
        v: v,
        fallbackAccent: theme.accent,
        fallbackIcon: theme.icon,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    ScaleTransition(
                      scale: _portraitScale,
                      child: _BossPortraitHero(theme: theme, v: v),
                    ),
                    AppSpacing.vGapLG,
                    Text(
                      widget.isMiniBoss ? 'MINI BOSS' : 'BOSS BATTLE',
                      style: t.bodySmall.copyWith(
                        color: v.red,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppSpacing.vGapSM,
                    Text(
                      widget.bossName.toUpperCase(),
                      style: t.heroTitle.copyWith(
                        fontSize: widget.isMiniBoss ? 26 : 32,
                        color: theme.accent,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapSM,
                    Text(
                      widget.isMiniBoss
                          ? 'First rival · Sets traps'
                          : theme.subtitle,
                      style: t.bodySmall.copyWith(color: v.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapLG,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: AppSpacing.roundedLG,
                        border: Border.all(
                          color: theme.accent.withValues(alpha: 0.35),
                        ),
                        color: theme.accent.withValues(alpha: 0.08),
                      ),
                      child: Text(
                        widget.isMiniBoss
                            ? '"Think you\'re ready? I\'ve been setting traps all match."'
                            : '"${theme.introLine}"',
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
                      label: widget.isMiniBoss ? 'LET\'S GO' : 'BEGIN FIGHT',
                      color: v.red,
                      width: double.infinity,
                      onPressed: _begin,
                    ),
                    AppSpacing.vGapMD,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BossPortraitHero extends StatelessWidget {
  const _BossPortraitHero({
    required this.theme,
    required this.v,
  });

  final BossPersonaTheme theme;
  final DotClashVisuals v;

  static const _size = 140.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: AppSpacing.roundedXL,
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.75),
          width: 2,
        ),
        boxShadow: v.useGlow
            ? [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.45),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.roundedXL,
        child: Image.asset(
          theme.portraitAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  theme.accent.withValues(alpha: 0.35),
                  theme.accent.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Icon(theme.icon, color: theme.accent, size: 56),
          ),
        ),
      ),
    );
  }
}
