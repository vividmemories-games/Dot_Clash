import '../../game/domain/models/game_state.dart';
import '../../game/domain/rules/game_rules.dart';

/// When a tutorial step becomes active.
enum TutorialStepEnter {
  /// First step when the match loads.
  sessionStart,

  /// After the human draws any line.
  onHumanMove,

  /// After the human claims a box.
  onHumanBoxClaimed,
}

/// How the player advances past the current step.
enum TutorialAdvanceTrigger {
  onDismiss,
  onHumanMove,
}

enum TutorialPresentation {
  fullScreen,
  banner,
}

enum TutorialHighlightRegion {
  none,
  board,
  scoreStrip,
}

enum TutorialEdgeTarget {
  none,
  firstLegalMove,
}

class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.body,
    this.title,
    this.enterWhen = TutorialStepEnter.sessionStart,
    this.presentation = TutorialPresentation.banner,
    this.advanceOn = TutorialAdvanceTrigger.onDismiss,
    this.highlightRegion = TutorialHighlightRegion.none,
    this.edgeTarget = TutorialEdgeTarget.none,
    this.blocksInteraction = false,
    this.showSkip = false,
  });

  final String id;
  final String? title;
  final String body;
  final TutorialStepEnter enterWhen;
  final TutorialPresentation presentation;
  final TutorialAdvanceTrigger advanceOn;
  final TutorialHighlightRegion highlightRegion;
  final TutorialEdgeTarget edgeTarget;
  final bool blocksInteraction;
  final bool showSkip;

  bool get isFullScreen => presentation == TutorialPresentation.fullScreen;
}

/// Pure Dart session logic — testable without Flutter/Riverpod.
class TutorialSessionLogic {
  TutorialSessionLogic({
    required this.levelId,
    required this.steps,
    this.stepIndex = 0,
    this.skipped = false,
  });

  final String levelId;
  final List<TutorialStep> steps;
  int stepIndex;
  bool skipped;

  bool get isComplete => skipped || stepIndex >= steps.length;

  TutorialStep? get currentStep {
    if (isComplete || steps.isEmpty) return null;
    return steps[stepIndex.clamp(0, steps.length - 1)];
  }

  bool get blocksInteraction =>
      !isComplete && (currentStep?.blocksInteraction ?? false);

  bool get showSkipButton =>
      !isComplete && (currentStep?.showSkip ?? false);

  /// Resolves the edge to pulse for the current step, if any.
  String? highlightEdge(GameState state) {
    final step = currentStep;
    if (step == null) return null;
    return switch (step.edgeTarget) {
      TutorialEdgeTarget.firstLegalMove => _firstLegalMove(state),
      TutorialEdgeTarget.none => null,
    };
  }

  /// When set, only these edges accept taps during the current step.
  Set<String>? allowedEdges(GameState state) {
    final edge = highlightEdge(state);
    if (edge == null) return null;
    return {edge};
  }

  /// Returns true when the step index changed.
  bool onHumanMove() {
    if (isComplete) return false;
    final step = currentStep;
    if (step == null) return false;

    if (step.advanceOn == TutorialAdvanceTrigger.onHumanMove) {
      return _advance();
    }

    // w1_l01: step 0 advances on first human move.
    if (stepIndex == 0 &&
        steps.length > 1 &&
        steps[1].enterWhen == TutorialStepEnter.onHumanMove) {
      stepIndex = 1;
      return true;
    }
    return false;
  }

  /// Returns true when the step index changed.
  bool onHumanBoxClaimed() {
    if (isComplete) return false;

    for (var i = 0; i < steps.length; i++) {
      if (steps[i].enterWhen == TutorialStepEnter.onHumanBoxClaimed &&
          stepIndex < i) {
        stepIndex = i;
        return true;
      }
    }
    return false;
  }

  /// Returns true when the step index changed or tutorial completed.
  bool dismissCurrentStep() {
    if (isComplete) return false;
    final step = currentStep;
    if (step == null) return false;
    if (step.advanceOn != TutorialAdvanceTrigger.onDismiss) return false;
    return _advance();
  }

  void skipAll() {
    skipped = true;
    stepIndex = steps.length;
  }

  bool _advance() {
    stepIndex++;
    _skipUnreachedReactiveSteps();
    return true;
  }

  /// Skips steps that only activate on game events the player has not hit yet.
  void _skipUnreachedReactiveSteps() {
    while (stepIndex < steps.length &&
        steps[stepIndex].enterWhen == TutorialStepEnter.onHumanBoxClaimed) {
      stepIndex++;
    }
  }

  static String? _firstLegalMove(GameState state) {
    final moves = GameRules.legalMoves(state);
    if (moves.isEmpty) return null;
    moves.sort();
    return moves.first;
  }
}
