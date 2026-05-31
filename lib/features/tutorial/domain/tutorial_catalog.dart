import 'tutorial_step.dart';

/// Campaign levels that include guided tutorial overlays.
abstract final class TutorialCatalog {
  static const tutorialLevelIds = ['w1_l01', 'w1_l02', 'w1_l03'];

  static bool isTutorialLevel(String levelId) =>
      tutorialLevelIds.contains(levelId);

  static List<TutorialStep> stepsFor(String levelId) =>
      switch (levelId) {
        'w1_l01' => _w1L01Steps,
        'w1_l02' => _w1L02Steps,
        'w1_l03' => _w1L03Steps,
        _ => const [],
      };

  static const _w1L01Steps = [
    TutorialStep(
      id: 'w1_l01_draw',
      title: 'Your first move',
      body: 'Tap the glowing line to draw your first move.',
      presentation: TutorialPresentation.banner,
      advanceOn: TutorialAdvanceTrigger.onHumanMove,
      highlightRegion: TutorialHighlightRegion.board,
      edgeTarget: TutorialEdgeTarget.firstLegalMove,
      showSkip: false,
    ),
    TutorialStep(
      id: 'w1_l01_boxes',
      title: 'Make boxes',
      body:
          'Connect dots to make boxes. When four sides close, you claim it and score!',
      enterWhen: TutorialStepEnter.onHumanMove,
      presentation: TutorialPresentation.banner,
      advanceOn: TutorialAdvanceTrigger.onDismiss,
      showSkip: true,
    ),
    TutorialStep(
      id: 'w1_l01_extra_turn',
      title: 'Extra turn!',
      body: 'Nice capture! You get another turn immediately.',
      enterWhen: TutorialStepEnter.onHumanBoxClaimed,
      presentation: TutorialPresentation.banner,
      advanceOn: TutorialAdvanceTrigger.onDismiss,
      showSkip: true,
    ),
  ];

  static const _w1L02Steps = [
    TutorialStep(
      id: 'w1_l02_score',
      title: 'Watch the score',
      body: 'Most boxes wins. Watch the score as you play.',
      presentation: TutorialPresentation.fullScreen,
      advanceOn: TutorialAdvanceTrigger.onDismiss,
      highlightRegion: TutorialHighlightRegion.scoreStrip,
      blocksInteraction: true,
      showSkip: true,
    ),
  ];

  static const _w1L03Steps = [
    TutorialStep(
      id: 'w1_l03_corners',
      title: 'Corner tip',
      body:
          'Tip: corner boxes have fewer sides to defend. Claim them when you can.',
      presentation: TutorialPresentation.banner,
      advanceOn: TutorialAdvanceTrigger.onDismiss,
      showSkip: true,
    ),
  ];
}
