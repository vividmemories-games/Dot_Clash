import 'package:flutter/material.dart';

import '../../core/theme/dot_clash_visuals.dart';

/// Base scaffold with consistent background gradient.
///
/// The gradient blends from the theme's [DotClashVisuals.backgroundGradientTop]
/// down into [DotClashVisuals.scaffold], so it reads as a glow-tinted sky on
/// neon and a softly-vignetted page on paper.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
    this.withGradient = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;
  final bool withGradient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: withGradient ? _GradientBackground(child: body) : body,
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.2,
          colors: [v.backgroundGradientTop, v.scaffold],
        ),
      ),
      child: child,
    );
  }
}
