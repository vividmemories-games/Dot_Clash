import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/feedback/app_haptics.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';
import '../domain/coach_tour_step.dart';
import 'coach_tour_target.dart';

class SpotlightOverlay extends StatefulWidget {
  const SpotlightOverlay({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.showSkip,
    required this.onNext,
    required this.onSkip,
    this.continueLabel = 'NEXT',
  });

  final CoachTourStep step;
  final int stepIndex;
  final int totalSteps;
  final bool showSkip;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final String continueLabel;

  @override
  State<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<SpotlightOverlay> {
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHole());
  }

  @override
  void didUpdateWidget(SpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id ||
        oldWidget.step.targetId != widget.step.targetId ||
        oldWidget.stepIndex != widget.stepIndex) {
      setState(() => _hole = null);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureHole());
    }
  }

  void _measureHole() {
    if (!mounted) return;
    final global = CoachTourTargetRegistry.boundsFor(widget.step.targetId);
    Rect? local;
    if (global != null && global.width > 0 && global.height > 0) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final topLeft = box.globalToLocal(global.topLeft);
        final bottomRight = box.globalToLocal(global.bottomRight);
        local = Rect.fromPoints(topLeft, bottomRight);
      }
    }
    setState(() => _hole = local);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final hole = _hole;
    final isFullScreen = widget.step.isFullScreen || hole == null;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _SpotlightScrim(hole: isFullScreen ? null : hole),
          if (widget.showSkip)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () {
                    AppHaptics.lightImpact();
                    widget.onSkip();
                  },
                  child: Text(
                    'SKIP TOUR',
                    style: t.scoreLabel.copyWith(
                      color: v.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          _CalloutCard(
            step: widget.step,
            stepIndex: widget.stepIndex,
            totalSteps: widget.totalSteps,
            hole: isFullScreen ? null : hole,
            continueLabel: widget.continueLabel,
            onNext: () {
              AppHaptics.lightImpact();
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

class _SpotlightScrim extends StatelessWidget {
  const _SpotlightScrim({this.hole});

  final Rect? hole;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _SpotlightPainter(hole: hole),
          child: const SizedBox.expand(),
        ),
        if (hole == null)
          GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          )
        else
          ..._holeBlockers(hole!),
      ],
    );
  }

  /// Dimmed regions only — the spotlight hole stays tappable.
  static List<Widget> _holeBlockers(Rect hole) {
    final cutout = hole.inflate(8);
    return [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: cutout.top.clamp(0, double.infinity),
        child: _TapBlocker(),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: cutout.bottom,
        bottom: 0,
        child: _TapBlocker(),
      ),
      Positioned(
        left: 0,
        top: cutout.top,
        width: cutout.left.clamp(0, double.infinity),
        height: cutout.height,
        child: _TapBlocker(),
      ),
      Positioned(
        left: cutout.right,
        top: cutout.top,
        right: 0,
        height: cutout.height,
        child: _TapBlocker(),
      ),
    ];
  }
}

class _TapBlocker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: const SizedBox.expand(),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({this.hole});

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      final padded = hole!.inflate(8);
      final holePath = Path()
        ..addRRect(RRect.fromRectAndRadius(padded, const Radius.circular(12)));
      final combined =
          Path.combine(PathOperation.difference, overlay, holePath);
      canvas.drawPath(
        combined,
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );
    } else {
      canvas.drawPath(
        overlay,
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.hole != hole;
}

class _CalloutCard extends StatelessWidget {
  const _CalloutCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.hole,
    required this.continueLabel,
    required this.onNext,
  });

  final CoachTourStep step;
  final int stepIndex;
  final int totalSteps;
  final Rect? hole;
  final String continueLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final screen = MediaQuery.sizeOf(context);

    final card = _buildCard(v, t);

    if (hole == null) {
      return SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            children: [
              const Spacer(flex: 2),
              card,
              const Spacer(flex: 3),
            ],
          ),
        ),
      );
    }

    final holeBottom = hole!.bottom;
    final placeAbove = holeBottom > screen.height * 0.55;
    final top = placeAbove ? 72.0 : holeBottom + 16;
    final bottom = placeAbove ? screen.height - hole!.top + 16 : 24.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Align(
          alignment: placeAbove ? Alignment.topCenter : Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              top: placeAbove ? top : 0,
              bottom: placeAbove ? 0 : bottom,
            ),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(DotClashVisuals v, AppTextStyles t) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: v.surface.withValues(alpha: 0.96),
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.playerA.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
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
                Text(
                  'TUTORIAL',
                  style: t.scoreLabel.copyWith(
                    color: v.playerA,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${stepIndex + 1}/$totalSteps',
                  style: t.scoreLabel.copyWith(color: v.textSecondary),
                ),
              ],
            ),
            if (step.title != null) ...[
              AppSpacing.vGapSM,
              Text(step.title!, style: t.playerName.copyWith(fontSize: 16)),
            ],
            AppSpacing.vGapSM,
            Text(step.body, style: t.bodySmall.copyWith(height: 1.35)),
            AppSpacing.vGapMD,
            NeonButton(
              label: continueLabel,
              color: v.playerA,
              width: double.infinity,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}
