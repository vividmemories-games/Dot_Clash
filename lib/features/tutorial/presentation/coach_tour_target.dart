import 'package:flutter/material.dart';

import '../domain/coach_tour_step.dart';

/// Global registry of [GlobalKey]s for coach-tour spotlight targets.
///
/// Home/shell targets use a stable global map. Match targets use a separate
/// map keyed by an owning [GameScreen] scope so two play routes cannot share
/// the same [GlobalKey] during GoRouter transitions.
abstract final class CoachTourTargetRegistry {
  static final Map<CoachTourTargetId, GlobalKey> _homeKeys = {};
  static final Map<CoachTourTargetId, GlobalKey> _gameKeys = {};
  static Object? _gameScopeOwner;

  /// Targets on [GameScreen] (and its subtree). Never share keys with home.
  static const Set<CoachTourTargetId> gameTargetIds = {
    CoachTourTargetId.gameBoard,
    CoachTourTargetId.gameScoreStrip,
    CoachTourTargetId.gameObjectivesBar,
    CoachTourTargetId.gameObjectivesStar2,
    CoachTourTargetId.gameTurnTimer,
    CoachTourTargetId.gameHintButton,
    CoachTourTargetId.gamePowerUpHold,
    CoachTourTargetId.gamePowerUpPanel,
  };

  static bool isGameTarget(CoachTourTargetId id) => gameTargetIds.contains(id);

  /// Call before leaving a play route so the next frame cannot reuse keys.
  static void releaseAllGameTargets() {
    _gameKeys.clear();
    _gameScopeOwner = null;
  }

  /// Binds match targets to [owner]. Replaces keys when the owner changes.
  static void claimGameScope(Object owner) {
    if (_gameScopeOwner == owner) return;
    _gameKeys.clear();
    _gameScopeOwner = owner;
  }

  /// Drops match keys only if [owner] is still the active scope.
  static void releaseGameScope(Object owner) {
    if (_gameScopeOwner != owner) return;
    releaseAllGameTargets();
  }

  static GlobalKey keyForHome(CoachTourTargetId id) {
    assert(!isGameTarget(id));
    return _homeKeys.putIfAbsent(id, GlobalKey.new);
  }

  static GlobalKey keyForGame(CoachTourTargetId id, Object owner) {
    assert(isGameTarget(id));
    claimGameScope(owner);
    return _gameKeys.putIfAbsent(id, GlobalKey.new);
  }

  static Rect? boundsFor(CoachTourTargetId id) {
    if (id == CoachTourTargetId.none || id == CoachTourTargetId.homeWelcome) {
      return null;
    }
    final key = _gameKeys[id] ?? _homeKeys[id];
    if (key == null) return null;
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  @visibleForTesting
  static void clearForTest() {
    _homeKeys.clear();
    releaseAllGameTargets();
  }
}

/// Supplies the active match scope for [CoachTourTarget] game IDs.
class CoachTourGameScope extends InheritedWidget {
  const CoachTourGameScope({
    super.key,
    required this.owner,
    required super.child,
  });

  final Object owner;

  static CoachTourGameScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CoachTourGameScope>();
  }

  @override
  bool updateShouldNotify(CoachTourGameScope oldWidget) =>
      oldWidget.owner != owner;
}

/// Wraps a widget and registers it as a coach-tour spotlight target.
class CoachTourTarget extends StatelessWidget {
  const CoachTourTarget({
    super.key,
    required this.id,
    required this.child,
  });

  final CoachTourTargetId id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final GlobalKey subtreeKey;
    if (CoachTourTargetRegistry.isGameTarget(id)) {
      final scope = CoachTourGameScope.maybeOf(context);
      if (scope == null) {
        return child;
      }
      subtreeKey = CoachTourTargetRegistry.keyForGame(id, scope.owner);
    } else {
      subtreeKey = CoachTourTargetRegistry.keyForHome(id);
    }
    return KeyedSubtree(key: subtreeKey, child: child);
  }
}
