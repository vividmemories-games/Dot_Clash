import 'package:flutter/material.dart';

import '../../core/theme/dot_clash_visuals.dart';
import '../feedback/app_haptics.dart';
import '../layout/app_spacing.dart';

/// Primary action button with neon glow and optional icon.
class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.color,
    this.width,
    this.height = 52,
    this.fontSize = 14,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final Color? color;
  final double? width;
  final double height;
  final double fontSize;
  final bool enabled;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _controller.reverse();
    AppHaptics.lightImpact();
  }

  void _onPointerUp(PointerEvent event) {
    if (!widget.enabled) return;
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final base = widget.color ?? v.playerA;
    final effectiveColor = widget.enabled ? base : v.textDisabled;
    final fillOpacity = 0.15;

    final child = ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: widget.width,
        height: widget.height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: effectiveColor.withOpacity(fillOpacity),
          borderRadius: AppSpacing.roundedMD,
          border: Border.all(
            color: effectiveColor,
            width: 1.5,
          ),
          boxShadow: widget.enabled && v.useGlow
              ? [
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.35),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              AppSpacing.hGapSM,
            ] else if (widget.icon != null) ...[
              Icon(widget.icon, color: effectiveColor, size: 18),
              AppSpacing.hGapSM,
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: effectiveColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    // Listener fires on pointer down/up before the scroll gesture arena,
    // so press feedback still works inside ListView and other scrollables.
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onPressed : null,
        child: child,
      ),
    );
  }
}
