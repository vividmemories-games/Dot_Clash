import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Main bottom-nav tab indexes (must match [StatefulShellRoute] branch order).
abstract final class MainShellTabs {
  static const int home = 0;
  static const int campaign = 1;
  static const int profile = 2;
  static const int shop = 3;
  static const int count = 4;
}

abstract final class MainShellSwipeThresholds {
  static const double distance = 72;
  static const double velocity = 350;
}

/// AppShell registers [goToTab] so Shop can delegate edge swipes to Profile.
class MainShellNavigationHolder {
  void Function(int index)? goToTab;
}

final mainShellNavigationHolderProvider =
    Provider<MainShellNavigationHolder>((ref) => MainShellNavigationHolder());

/// Shop sub-tab index (0=Themes … 3=Boosts) for outer/inner swipe coordination.
final shopSubTabIndexProvider = StateProvider<int>((ref) => 0);

bool shouldOuterSwipeLeaveShop({
  required int shopSubTabIndexAtDragStart,
  required double dragDx,
  required double velocity,
}) {
  if (shopSubTabIndexAtDragStart != 0) return false;
  return dragDx > MainShellSwipeThresholds.distance ||
      velocity > MainShellSwipeThresholds.velocity;
}

/// Detects swipe-right on the first shop sub-tab and navigates to Profile.
///
/// Uses [Listener] so it still receives pointer events when [TabBarView] wins
/// the horizontal drag arena for inner sub-tab paging.
class ShopOuterSwipeBridge extends ConsumerStatefulWidget {
  const ShopOuterSwipeBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShopOuterSwipeBridge> createState() =>
      _ShopOuterSwipeBridgeState();
}

class _ShopOuterSwipeBridgeState extends ConsumerState<ShopOuterSwipeBridge> {
  TabController? _tabController;
  double _startX = 0;
  double _totalDx = 0;
  DateTime? _dragStartTime;
  int? _shopTabIndexAtDragStart;
  bool _tracking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.of(context);
    if (_tabController != next) {
      _tabController?.removeListener(_syncShopSubTabIndex);
      _tabController = next;
      _tabController?.addListener(_syncShopSubTabIndex);
      _syncShopSubTabIndex();
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_syncShopSubTabIndex);
    super.dispose();
  }

  void _syncShopSubTabIndex() {
    final controller = _tabController;
    if (controller == null) return;
    ref.read(shopSubTabIndexProvider.notifier).state = controller.index;
  }

  void _onPointerDown(PointerDownEvent event) {
    _startX = event.position.dx;
    _totalDx = 0;
    _dragStartTime = DateTime.now();
    _shopTabIndexAtDragStart = _tabController?.index;
    _tracking = true;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_tracking) return;
    _totalDx = event.position.dx - _startX;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_tracking) return;
    _tracking = false;

    final startIndex = _shopTabIndexAtDragStart;
    _shopTabIndexAtDragStart = null;
    if (startIndex == null) return;

    final dragMs = _dragStartTime == null
        ? 0
        : DateTime.now().difference(_dragStartTime!).inMilliseconds;
    _dragStartTime = null;
    final velocity = dragMs > 0 ? (_totalDx / dragMs) * 1000 : 0.0;

    // Themes (first sub-tab): swipe right → previous main tab (Profile).
    if (shouldOuterSwipeLeaveShop(
      shopSubTabIndexAtDragStart: startIndex,
      dragDx: _totalDx,
      velocity: velocity,
    )) {
      ref
          .read(mainShellNavigationHolderProvider)
          .goToTab
          ?.call(MainShellTabs.profile);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _tracking = false;
    _shopTabIndexAtDragStart = null;
    _dragStartTime = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
