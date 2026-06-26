import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/feedback/app_haptics.dart';
import '../../../../shared/layout/app_spacing.dart';
import 'game_rules_sheet.dart';

/// Collapsible MORE dock: Undo, Restart, Settings, How to Play, Exit.
class MatchMoreDock extends StatefulWidget {
  const MatchMoreDock({
    super.key,
    required this.canUndo,
    required this.onUndo,
    required this.onRestart,
    required this.onExit,
    this.extraTurnsAvailable = false,
    this.onExtraTurns,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final bool extraTurnsAvailable;
  final VoidCallback? onExtraTurns;

  @override
  State<MatchMoreDock> createState() => _MatchMoreDockState();
}

class _MatchMoreDockState extends State<MatchMoreDock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              AppHaptics.selectionClick();
              setState(() => _expanded = !_expanded);
            },
            borderRadius: AppSpacing.roundedMD,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'MORE',
                    style: t.scoreLabel.copyWith(
                      fontSize: 10,
                      color: v.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: v.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: v.surface,
                borderRadius: AppSpacing.roundedLG,
                border: Border.all(color: v.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DockAction(
                    icon: Icons.undo_rounded,
                    label: 'Undo',
                    color: v.undoColor,
                    enabled: widget.canUndo,
                    onTap: widget.onUndo,
                  ),
                  _DockAction(
                    icon: Icons.refresh_rounded,
                    label: 'Restart',
                    color: v.newGameColor,
                    onTap: widget.onRestart,
                  ),
                  if (widget.extraTurnsAvailable && widget.onExtraTurns != null)
                    _DockAction(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Extra',
                      color: v.gold,
                      onTap: widget.onExtraTurns!,
                    ),
                  _DockAction(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    color: v.textSecondary,
                    onTap: () => context.push('/settings'),
                  ),
                  _DockAction(
                    icon: Icons.help_outline_rounded,
                    label: 'Rules',
                    color: v.textSecondary,
                    onTap: () => showGameRulesSheet(context),
                  ),
                  _DockAction(
                    icon: Icons.logout_rounded,
                    label: 'Exit',
                    color: v.red,
                    onTap: widget.onExit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: enabled
            ? () {
                AppHaptics.lightImpact();
                onTap();
              }
            : null,
        borderRadius: AppSpacing.roundedSM,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: t.bodySmall.copyWith(fontSize: 9, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
