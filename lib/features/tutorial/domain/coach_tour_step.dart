import '../../game/domain/models/game_state.dart';
import '../../game/domain/rules/game_rules.dart';
import 'tutorial_step.dart';

/// Registered spotlight targets across Home and Game screens.
enum CoachTourTargetId {
  none,
  homeWelcome,
  homeCampaignHero,
  homeQuickMatch,
  homeDailyPuzzle,
  homeLocal,
  homeTopBarLives,
  homeNavCampaign,
  gameBoard,
  gameScoreStrip,
  gameObjectivesBar,
  gameObjectivesStar2,
  gameTurnTimer,
  gameHintButton,
  gamePowerUpHold,
  gamePowerUpPanel,
}

enum CoachAdvanceTrigger {
  next,
  tapTarget,
  humanMove,
  boxClaimed,
  hintUsed,
  rivalChain,
}

class CoachTourStep {
  const CoachTourStep({
    required this.id,
    required this.body,
    this.title,
    this.targetId = CoachTourTargetId.none,
    this.enterWhen = TutorialStepEnter.sessionStart,
    this.advanceOn = CoachAdvanceTrigger.next,
    this.edgeTarget = TutorialEdgeTarget.none,
    this.blocksInteraction = false,
    this.showSkip = false,
    this.skipIfTimerDisabled = false,
  });

  final String id;
  final String? title;
  final String body;
  final CoachTourTargetId targetId;
  final TutorialStepEnter enterWhen;
  final CoachAdvanceTrigger advanceOn;
  final TutorialEdgeTarget edgeTarget;
  final bool blocksInteraction;
  final bool showSkip;
  final bool skipIfTimerDisabled;

  bool get isFullScreen =>
      targetId == CoachTourTargetId.none ||
      targetId == CoachTourTargetId.homeWelcome;
}

/// Pure Dart coach-tour session logic.
class CoachTourSessionLogic {
  CoachTourSessionLogic({
    required this.tourId,
    required this.steps,
    this.stepIndex = 0,
    this.skipped = false,
  });

  final String tourId;
  final List<CoachTourStep> steps;
  int stepIndex;
  bool skipped;

  bool get isComplete => skipped || stepIndex >= steps.length;

  CoachTourStep? get currentStep {
    if (isComplete || steps.isEmpty) return null;
    return steps[stepIndex.clamp(0, steps.length - 1)];
  }

  bool get blocksInteraction =>
      !isComplete && (currentStep?.blocksInteraction ?? false);

  bool get showSkipButton => !isComplete && (currentStep?.showSkip ?? false);

  String? highlightEdge(GameState state) {
    final step = currentStep;
    if (step == null) return null;
    return switch (step.edgeTarget) {
      TutorialEdgeTarget.firstLegalMove => _firstLegalMove(state),
      TutorialEdgeTarget.none => null,
    };
  }

  Set<String>? allowedEdges(GameState state) {
    final edge = highlightEdge(state);
    if (edge == null) return null;
    return {edge};
  }

  /// Skip timer step when setting is off; returns true if index changed.
  bool applyConditionalSkips({required bool showTimer}) {
    if (isComplete) return false;
    final step = currentStep;
    if (step == null) return false;
    if (step.skipIfTimerDisabled && !showTimer) {
      return _advance();
    }
    return false;
  }

  bool advanceNext() {
    if (isComplete) return false;
    final step = currentStep;
    if (step == null) return false;
    final canNext = step.advanceOn == CoachAdvanceTrigger.next ||
        step.advanceOn == CoachAdvanceTrigger.tapTarget ||
        step.advanceOn == CoachAdvanceTrigger.hintUsed ||
        step.advanceOn == CoachAdvanceTrigger.humanMove ||
        step.advanceOn == CoachAdvanceTrigger.rivalChain;
    if (!canNext) return false;
    return _advance();
  }

  bool onHumanMove() {
    if (isComplete) return false;
    final step = currentStep;
    if (step == null) return false;

    if (step.advanceOn == CoachAdvanceTrigger.humanMove) {
      return _advance();
    }

    if (stepIndex == 0 &&
        steps.length > 1 &&
        steps[1].enterWhen == TutorialStepEnter.onHumanMove) {
      stepIndex = 1;
      return true;
    }
    return false;
  }

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

  bool onHintUsed() {
    if (isComplete) return false;
    final step = currentStep;
    if (step == null) return false;
    if (step.advanceOn != CoachAdvanceTrigger.hintUsed) return false;
    return _advance();
  }

  bool onRivalChain() {
    if (isComplete) return false;

    for (var i = 0; i < steps.length; i++) {
      if (steps[i].advanceOn == CoachAdvanceTrigger.rivalChain &&
          stepIndex < i) {
        stepIndex = i;
        return true;
      }
    }
    return false;
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

  void _skipUnreachedReactiveSteps() {
    while (stepIndex < steps.length) {
      final step = steps[stepIndex];
      final reactive = step.enterWhen == TutorialStepEnter.onHumanBoxClaimed ||
          step.advanceOn == CoachAdvanceTrigger.rivalChain;
      if (!reactive) break;
      if (step.enterWhen == TutorialStepEnter.onHumanBoxClaimed) {
        stepIndex++;
        continue;
      }
      break;
    }
  }

  static String? _firstLegalMove(GameState state) {
    final moves = GameRules.legalMoves(state);
    if (moves.isEmpty) return null;
    moves.sort();
    return moves.first;
  }
}
