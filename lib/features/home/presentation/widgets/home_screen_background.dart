import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/dot_clash_visuals.dart';

class HomeScreenBackground extends StatefulWidget {
  const HomeScreenBackground({super.key, required this.child});

  final Widget child;

  @override
  State<HomeScreenBackground> createState() => _HomeScreenBackgroundState();
}

class _HomeScreenBackgroundState extends State<HomeScreenBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Continuous slow loop — particles and gradient breathe indefinitely.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Gradient focal point breathes up and down gently.
        final gradientY = -0.65 + 0.14 * math.sin(t * math.pi * 2);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Base radial gradient — shifts subtly with the cycle.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, gradientY),
                  radius: 1.08,
                  colors: [v.backgroundGradientTop, v.scaffold],
                ),
              ),
            ),
            // Floating ambient orbs — kept very transparent for subtlety.
            IgnorePointer(
              child: CustomPaint(
                painter: _AmbientOrbPainter(
                  progress: t,
                  colorA: v.playerAGlow.withValues(alpha: 0.22),
                  colorB: v.green.withValues(alpha: 0.15),
                  colorC: v.playerBGlow.withValues(alpha: 0.12),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

/// Paints a handful of slowly drifting translucent orbs that give the
/// background a sense of depth and life without eating GPU budget.
class _AmbientOrbPainter extends CustomPainter {
  const _AmbientOrbPainter({
    required this.progress,
    required this.colorA,
    required this.colorB,
    required this.colorC,
  });

  final double progress;
  final Color colorA;
  final Color colorB;
  final Color colorC;

  static const _orbs = <({double x, double seed, double radius, int palette})>[
    (x: 0.08, seed: 0.00, radius: 32, palette: 0),
    (x: 0.26, seed: 0.18, radius: 20, palette: 1),
    (x: 0.50, seed: 0.40, radius: 38, palette: 0),
    (x: 0.68, seed: 0.60, radius: 22, palette: 2),
    (x: 0.85, seed: 0.75, radius: 28, palette: 1),
    (x: 0.38, seed: 0.88, radius: 18, palette: 2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in _orbs) {
      final phase = (progress + orb.seed) % 1.0;
      final y = size.height * phase;
      final xDrift = math.sin((progress + orb.seed) * math.pi * 2) * 10;
      final center = Offset(size.width * orb.x + xDrift, y);
      final color = switch (orb.palette) {
        0 => colorA,
        1 => colorB,
        _ => colorC,
      };
      canvas.drawCircle(center, orb.radius.toDouble(), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientOrbPainter old) =>
      old.progress != progress;
}
