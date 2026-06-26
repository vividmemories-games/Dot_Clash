import 'package:flutter/material.dart';

import '../../../../core/theme/dot_clash_visuals.dart';

/// Reusable boss portrait layer for intro cinematics and in-match backdrops.
class BossPortraitBackdrop extends StatelessWidget {
  const BossPortraitBackdrop({
    super.key,
    required this.portraitAsset,
    required this.v,
    required this.child,
    this.imageOpacity = 0.22,
    this.scrimStrength = 0.78,
    this.alignment = Alignment.center,
    this.fallbackAccent,
    this.fallbackIcon,
  });

  /// Full-screen intro: portrait prominent, lighter scrim.
  const BossPortraitBackdrop.intro({
    super.key,
    required this.portraitAsset,
    required this.v,
    required this.child,
    this.alignment = const Alignment(0, -0.15),
    this.fallbackAccent,
    this.fallbackIcon,
  })  : imageOpacity = 0.92,
        scrimStrength = 0.52;

  /// In-match arena: portrait subtle, heavy scrim for board readability.
  const BossPortraitBackdrop.gameplay({
    super.key,
    required this.portraitAsset,
    required this.v,
    required this.child,
    this.alignment = const Alignment(0, -0.35),
    this.fallbackAccent,
    this.fallbackIcon,
  })  : imageOpacity = 0.18,
        scrimStrength = 0.82;

  final String portraitAsset;
  final DotClashVisuals v;
  final Widget child;
  final double imageOpacity;
  final double scrimStrength;
  final Alignment alignment;
  final Color? fallbackAccent;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: imageOpacity,
            child: Image.asset(
              portraitAsset,
              fit: BoxFit.cover,
              alignment: alignment,
              errorBuilder: (_, __, ___) => _PortraitFallback(
                accent: fallbackAccent ?? v.red,
                icon: fallbackIcon ?? Icons.warning_rounded,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: scrimStrength * 0.9),
                  v.scaffold.withValues(alpha: 0.88),
                  v.scaffold.withValues(alpha: 0.96),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback({
    required this.accent,
    required this.icon,
  });

  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.25),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, color: accent.withValues(alpha: 0.6), size: 72),
      ),
    );
  }
}
