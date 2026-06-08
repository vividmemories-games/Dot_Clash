import 'dart:math';

import 'package:flutter/material.dart';

/// Lightweight dots-and-lines confetti for 2–3 star wins.
class DotConfettiLayer extends StatefulWidget {
  const DotConfettiLayer({super.key, required this.active});

  final bool active;

  @override
  State<DotConfettiLayer> createState() => _DotConfettiLayerState();
}

class _DotConfettiLayerState extends State<DotConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _random = Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = _spawnParticles();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.active) _ctrl.forward();
  }

  @override
  void didUpdateWidget(DotConfettiLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _particles = _spawnParticles();
      _ctrl.forward(from: 0);
    }
  }

  List<_Particle> _spawnParticles() {
    return List.generate(28, (_) {
      return _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble() * 0.35,
        vx: (_random.nextDouble() - 0.5) * 0.35,
        vy: 0.25 + _random.nextDouble() * 0.45,
        size: 3 + _random.nextDouble() * 4,
        isLine: _random.nextBool(),
        hue: _random.nextInt(3),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _DotConfettiPainter(
            progress: _ctrl.value,
            particles: _particles,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.isLine,
    required this.hue,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final bool isLine;
  final int hue;
}

class _DotConfettiPainter extends CustomPainter {
  _DotConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_Particle> particles;

  static const _colors = [
    Color(0xFF64B5F6),
    Color(0xFFCE93D8),
    Color(0xFFFFD54F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress.clamp(0.0, 1.0);
      final px = (p.x + p.vx * t) * size.width;
      final py = (p.y + p.vy * t) * size.height;
      final opacity = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color =
            _colors[p.hue % _colors.length].withValues(alpha: opacity * 0.9)
        ..strokeWidth = 2
        ..style = p.isLine ? PaintingStyle.stroke : PaintingStyle.fill;
      if (p.isLine) {
        canvas.drawLine(
          Offset(px, py),
          Offset(px + p.size * 3, py + p.size),
          paint,
        );
      } else {
        canvas.drawCircle(Offset(px, py), p.size * 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
