import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/theme/dot_clash_visuals.dart';
import '../../features/profile/providers/profile_bootstrap_provider.dart';
import '../../features/tutorial/domain/coach_tour_step.dart';
import 'profile_bootstrap_screen.dart';
import '../../features/tutorial/presentation/coach_tour_target.dart';
import '../../features/tutorial/presentation/spotlight_overlay.dart';
import '../../features/tutorial/providers/coach_tour_provider.dart';
import '../layout/app_spacing.dart';
import '../navigation/main_shell_swipe.dart';

/// Persistent shell that renders the active tab above a custom bottom nav bar.
///
/// Receives [navigationShell] from GoRouter's [StatefulShellRoute.indexedStack]
/// and forwards branch switching via [StatefulNavigationShell.goBranch].
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  void _goToTab(int index) {
    final shell = widget.navigationShell;
    if (index < 0 || index >= MainShellTabs.count) return;
    shell.goBranch(
      index,
      initialLocation: index == shell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.read(mainShellNavigationHolderProvider).goToTab = _goToTab;

    final bootstrap = ref.watch(profileBootstrapProvider);
    if (bootstrap == ProfileBootstrapState.loading) {
      return const ProfileBootstrapScreen();
    }
    if (bootstrap == ProfileBootstrapState.error) {
      return const ProfileBootstrapErrorScreen();
    }

    final v = context.dc;
    final homeTour = ref.watch(homeCoachTourProvider);
    final onHomeTab = widget.navigationShell.currentIndex == 0;
    final swipeEnabled = !(onHomeTab && homeTour.isActive);

    if (onHomeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(homeCoachTourProvider.notifier).maybeStart();
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: v.scaffold,
          body: _TabSwipeLayer(
            enabled: swipeEnabled,
            currentIndex: widget.navigationShell.currentIndex,
            onTabChange: _goToTab,
            child: widget.navigationShell,
          ),
          bottomNavigationBar: _BottomNav(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _goToTab,
          ),
        ),
        if (onHomeTab && homeTour.isActive && homeTour.logic != null)
          _HomeTourOverlay(logic: homeTour.logic!),
      ],
    );
  }
}

class _HomeTourOverlay extends ConsumerWidget {
  const _HomeTourOverlay({required this.logic});

  final CoachTourSessionLogic logic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = logic.currentStep;
    if (step == null) return const SizedBox.shrink();

    return SpotlightOverlay(
      step: step,
      stepIndex: logic.stepIndex,
      totalSteps: logic.steps.length,
      showSkip: logic.showSkipButton,
      onNext: () => ref.read(homeCoachTourProvider.notifier).advanceNext(),
      onSkip: () => ref.read(homeCoachTourProvider.notifier).skipAll(),
    );
  }
}

/// Horizontal swipe between main tabs (Home / Campaign / Profile / Shop).
class _TabSwipeLayer extends StatefulWidget {
  const _TabSwipeLayer({
    required this.enabled,
    required this.currentIndex,
    required this.onTabChange,
    required this.child,
  });

  final bool enabled;
  final int currentIndex;
  final void Function(int index) onTabChange;
  final Widget child;

  @override
  State<_TabSwipeLayer> createState() => _TabSwipeLayerState();
}

class _TabSwipeLayerState extends State<_TabSwipeLayer> {
  double _dragDx = 0;

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    // Shop delegates swipe-right-at-Themes to [ShopOuterSwipeBridge].
    if (widget.currentIndex == MainShellTabs.shop) return;

    final velocity = details.primaryVelocity ?? 0;
    final swipeLeft = _dragDx < -MainShellSwipeThresholds.distance ||
        velocity < -MainShellSwipeThresholds.velocity;
    final swipeRight = _dragDx > MainShellSwipeThresholds.distance ||
        velocity > MainShellSwipeThresholds.velocity;

    if (swipeLeft && widget.currentIndex < MainShellTabs.count - 1) {
      widget.onTabChange(widget.currentIndex + 1);
    } else if (swipeRight && widget.currentIndex > 0) {
      widget.onTabChange(widget.currentIndex - 1);
    }
    _dragDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: widget.enabled ? (_) => _dragDx = 0 : null,
      onHorizontalDragUpdate:
          widget.enabled ? (details) => _dragDx += details.delta.dx : null,
      onHorizontalDragEnd: widget.enabled ? _onHorizontalDragEnd : null,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

// ── Custom bottom nav bar ─────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  static const _destinations =
      <({IconData icon, IconData iconSelected, String label})>[
    (
      icon: Icons.home_outlined,
      iconSelected: Icons.home_rounded,
      label: 'HOME',
    ),
    (
      icon: Icons.map_outlined,
      iconSelected: Icons.map_rounded,
      label: 'CAMPAIGN',
    ),
    (
      icon: Icons.person_outline_rounded,
      iconSelected: Icons.person_rounded,
      label: 'PROFILE',
    ),
    (
      icon: Icons.storefront_outlined,
      iconSelected: Icons.storefront_rounded,
      label: 'SHOP',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: v.surface,
          border: Border(
            top: BorderSide(color: v.cardBorder, width: 1),
          ),
          boxShadow: v.useGlow
              ? [
                  BoxShadow(
                    color: v.playerA.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            for (var i = 0; i < _destinations.length; i++)
              Expanded(
                child: i == 1
                    ? CoachTourTarget(
                        id: CoachTourTargetId.homeNavCampaign,
                        child: _NavItem(
                          icon: _destinations[i].icon,
                          iconSelected: _destinations[i].iconSelected,
                          label: _destinations[i].label,
                          selected: i == currentIndex,
                          onTap: () => onTap(i),
                        ),
                      )
                    : _NavItem(
                        icon: _destinations[i].icon,
                        iconSelected: _destinations[i].iconSelected,
                        label: _destinations[i].label,
                        selected: i == currentIndex,
                        onTap: () => onTap(i),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.iconSelected,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconSelected;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final color = selected ? v.playerA : v.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? v.playerA.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: AppSpacing.roundedFull,
              ),
              child: Icon(
                selected ? iconSelected : icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: t.scoreLabel.copyWith(
                color: color,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
