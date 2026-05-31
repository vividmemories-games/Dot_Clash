import 'coach_tour_step.dart';
import 'tutorial_step.dart';

abstract final class CoachTourCatalog {
  static const campaignFtueLevelIds = ['w1_l01', 'w1_l02', 'w1_l03', 'w1_l04'];

  static bool isCampaignFtueLevel(String levelId) =>
      campaignFtueLevelIds.contains(levelId);

  static List<CoachTourStep> homeFtueSteps = const [
    CoachTourStep(
      id: 'home_welcome',
      title: 'Welcome!',
      body:
          'Remember this game from class? Here\'s a quick tour of where everything lives.',
      targetId: CoachTourTargetId.homeWelcome,
      showSkip: false,
    ),
    CoachTourStep(
      id: 'home_campaign',
      title: 'Campaign',
      body:
          'Your main path — 100 levels, stars to earn, and rivals to beat. Losses cost a life.',
      targetId: CoachTourTargetId.homeCampaignHero,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'home_quick_match',
      title: 'Quick Match',
      body:
          'Jump into a match anytime vs a tough AI. Great for practice — no life cost.',
      targetId: CoachTourTargetId.homeQuickMatch,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'home_daily',
      title: 'Daily Puzzle',
      body:
          'Same board for everyone today. Beat it to grow your streak and earn coins.',
      targetId: CoachTourTargetId.homeDailyPuzzle,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'home_local',
      title: 'Local Play',
      body: 'Pass-and-play with a friend on this device — just like the notebook days.',
      targetId: CoachTourTargetId.homeLocal,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'home_lives',
      title: 'Lives & Coins',
      body:
          'Lives let you play Campaign. Coins buy refills, cosmetics, and boosts in the Shop.',
      targetId: CoachTourTargetId.homeTopBarLives,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'home_nav_campaign',
      title: 'Campaign Map',
      body: 'The full world map lives here — replay levels to chase more stars.',
      targetId: CoachTourTargetId.homeNavCampaign,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'home_start',
      title: 'You\'re Ready!',
      body: 'Tap Continue to start Level 1 — we\'ll teach you the rules in the match.',
      targetId: CoachTourTargetId.homeCampaignHero,
      showSkip: true,
    ),
  ];

  static List<CoachTourStep> campaignStepsFor(String levelId) =>
      switch (levelId) {
        'w1_l01' => _w1L01,
        'w1_l02' => _w1L02,
        'w1_l03' => _w1L03,
        'w1_l04' => _w1L04,
        _ => const [],
      };

  static const _w1L01 = [
    CoachTourStep(
      id: 'l01_draw',
      title: 'Your First Move',
      body: 'Tap the glowing line to draw your first move.',
      targetId: CoachTourTargetId.gameBoard,
      advanceOn: CoachAdvanceTrigger.humanMove,
      edgeTarget: TutorialEdgeTarget.firstLegalMove,
      showSkip: false,
    ),
    CoachTourStep(
      id: 'l01_score',
      title: 'Watch the Score',
      body: 'Most boxes wins. Keep an eye on the score as you play.',
      targetId: CoachTourTargetId.gameScoreStrip,
      enterWhen: TutorialStepEnter.onHumanMove,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'l01_extra_turn',
      title: 'Extra Turn!',
      body: 'Nice capture! Closing a box gives you another turn immediately.',
      targetId: CoachTourTargetId.gameScoreStrip,
      enterWhen: TutorialStepEnter.onHumanBoxClaimed,
      showSkip: true,
    ),
  ];

  static const _w1L02 = [
    CoachTourStep(
      id: 'l02_objectives',
      title: 'Star Goals',
      body:
          'Each level has three star goals. Hit them for bonus coins and bragging rights.',
      targetId: CoachTourTargetId.gameObjectivesBar,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'l02_star2',
      title: 'Bonus Star',
      body: 'This level\'s ★2 asks you to win by a margin — check the pill for details.',
      targetId: CoachTourTargetId.gameObjectivesStar2,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'l02_score',
      title: 'Score = Stars',
      body: 'Your live score drives those star goals. Play to the objectives!',
      targetId: CoachTourTargetId.gameScoreStrip,
      showSkip: true,
    ),
  ];

  static const _w1L03 = [
    CoachTourStep(
      id: 'l03_timer',
      title: 'Turn Timer',
      body: 'You have 30 seconds per turn. Act before time runs out!',
      targetId: CoachTourTargetId.gameTurnTimer,
      skipIfTimerDisabled: true,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'l03_hint',
      title: 'Hints',
      body: 'Stuck? Tap Hint for a suggested line — you get 3 per match.',
      targetId: CoachTourTargetId.gameHintButton,
      advanceOn: CoachAdvanceTrigger.hintUsed,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'l03_corners',
      title: 'Corner Tip',
      body: 'Corner boxes have fewer sides to defend. Claim them when you can.',
      targetId: CoachTourTargetId.gameBoard,
      showSkip: true,
    ),
  ];

  static const _w1L04 = [
    CoachTourStep(
      id: 'l04_chain_obj',
      title: 'Chain Trap',
      body: '★2 here: don\'t let the rival capture 3+ boxes in a row.',
      targetId: CoachTourTargetId.gameObjectivesBar,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'l04_trap',
      title: 'Avoid the Trap',
      body: 'Never give the rival the 3rd side of a box — that starts a chain.',
      targetId: CoachTourTargetId.gameBoard,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'l04_hold',
      title: 'Hold Boost',
      body: 'Tap Hold to skip the rival\'s next turn. You have one — use it wisely!',
      targetId: CoachTourTargetId.gamePowerUpHold,
      advanceOn: CoachAdvanceTrigger.tapTarget,
      showSkip: true,
    ),
    CoachTourStep(
      id: 'l04_riposte',
      title: 'Rival Chain!',
      body:
          'If they chain 3+ boxes, Riposte can undo their combo. You\'ll earn more boosts from bosses.',
      targetId: CoachTourTargetId.gamePowerUpPanel,
      showSkip: true,
    ),
  ];

  /// Post-win spotlight after mini boss grants power-ups.
  static const miniBossPowerUpStep = CoachTourStep(
    id: 'l05_powerups',
    title: 'Boosts Unlocked!',
    body: 'You earned Hold and Riposte. Tap them in the panel below during tough spots.',
    targetId: CoachTourTargetId.gamePowerUpPanel,
    showSkip: true,
  );
}
