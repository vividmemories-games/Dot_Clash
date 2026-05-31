import 'package:flutter/material.dart';

/// Subtle full-screen radial wash that shifts with whose turn it is.
class TurnAmbientBackdrop extends StatelessWidget {
  const TurnAmbientBackdrop({
    super.key,
    required this.isHumanTurn,
    required this.humanColor,
    required this.opponentColor,
    required this.child,
    this.enabled = true,
  });

  /// When true, [humanColor] wash; otherwise [opponentColor] (AI / P2 / boss).
  final bool isHumanTurn;
  final Color humanColor;
  final Color opponentColor;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final active = isHumanTurn ? humanColor : opponentColor;
    final centerOpacity = 0.08;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.5),
              radius: 1.25,
              colors: [
                active.withOpacity(centerOpacity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
