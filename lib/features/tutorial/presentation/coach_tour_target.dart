import 'package:flutter/material.dart';

import '../domain/coach_tour_step.dart';

/// Global registry of [GlobalKey]s for coach-tour spotlight targets.
abstract final class CoachTourTargetRegistry {
  static final Map<CoachTourTargetId, GlobalKey> _keys = {};

  static GlobalKey keyFor(CoachTourTargetId id) {
    return _keys.putIfAbsent(id, GlobalKey.new);
  }

  static Rect? boundsFor(CoachTourTargetId id) {
    if (id == CoachTourTargetId.none || id == CoachTourTargetId.homeWelcome) {
      return null;
    }
    final key = _keys[id];
    if (key == null) return null;
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  @visibleForTesting
  static void clearForTest() => _keys.clear();
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
    return KeyedSubtree(
      key: CoachTourTargetRegistry.keyFor(id),
      child: child,
    );
  }
}
