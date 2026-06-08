import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/analytics/analytics_service.dart';
import '../../game/domain/models/game_state.dart';
import '../../powerups/domain/power_up.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/ftue_preferences.dart';
import '../domain/coach_tour_catalog.dart';
import '../domain/coach_tour_step.dart';

final ftuePreferencesProvider =
    FutureProvider<FtuePreferences>((ref) => FtuePreferences.load());

final shouldShowCampaignFtueProvider =
    Provider.family<bool, String>((ref, levelId) {
  final prefs = ref.watch(ftuePreferencesProvider).valueOrNull;
  if (prefs == null) return false;
  return prefs.shouldShowCampaignFtue(levelId);
});

final tutorialFreeAttemptProvider =
    Provider.family<bool, String>((ref, levelId) {
  return ref.watch(shouldShowCampaignFtueProvider(levelId));
});

final tutorialHeroCopyProvider = Provider<bool>((ref) {
  final prefs = ref.watch(ftuePreferencesProvider).valueOrNull;
  return prefs?.shouldShowTutorialOnHero ?? false;
});

// ── Home coach tour ───────────────────────────────────────────────────────────

class HomeCoachTourState {
  const HomeCoachTourState({this.logic, this.active = false});

  final CoachTourSessionLogic? logic;
  final bool active;

  bool get isActive => active && logic != null && !(logic!.isComplete);

  HomeCoachTourState copyWith({CoachTourSessionLogic? logic, bool? active}) {
    return HomeCoachTourState(
      logic: logic ?? this.logic,
      active: active ?? this.active,
    );
  }
}

class HomeCoachTourNotifier extends StateNotifier<HomeCoachTourState> {
  HomeCoachTourNotifier(this._ref) : super(const HomeCoachTourState());

  final Ref _ref;

  Future<void> maybeStart() async {
    if (state.isActive) return;
    final prefs = await _ref.read(ftuePreferencesProvider.future);
    if (!prefs.shouldShowHomeTour) return;

    state = HomeCoachTourState(
      active: true,
      logic: CoachTourSessionLogic(
        tourId: 'home_ftue_v1',
        steps: CoachTourCatalog.homeFtueSteps,
      ),
    );
    await AnalyticsService.instance.logHomeTourBegin();
  }

  void advanceNext() {
    final logic = state.logic;
    if (logic == null || logic.isComplete) return;
    logic.advanceNext();
    state = state.copyWith(logic: logic);
    _logStep(logic);
    _maybeComplete(logic);
  }

  Future<void> skipAll() async {
    final logic = state.logic;
    if (logic == null) return;
    logic.skipAll();
    state = state.copyWith(logic: logic, active: false);
    await FtuePreferences.skipHomeTour();
    _ref.invalidate(ftuePreferencesProvider);
    await AnalyticsService.instance.logHomeTourSkip();
  }

  Future<void> _maybeComplete(CoachTourSessionLogic logic) async {
    if (!logic.isComplete || logic.skipped) return;
    await FtuePreferences.markHomeTourComplete();
    _ref.invalidate(ftuePreferencesProvider);
    state = state.copyWith(active: false);
    await AnalyticsService.instance.logHomeTourComplete();
  }

  void _logStep(CoachTourSessionLogic logic) {
    final step = logic.currentStep;
    if (step == null) return;
    AnalyticsService.instance.logHomeTourStep(
      stepId: step.id,
      stepIndex: logic.stepIndex,
      targetId: step.targetId.name,
    );
  }

  void reset() => state = const HomeCoachTourState();
}

final homeCoachTourProvider =
    StateNotifierProvider<HomeCoachTourNotifier, HomeCoachTourState>(
  HomeCoachTourNotifier.new,
);

// ── Match coach tour ──────────────────────────────────────────────────────────

class MatchCoachTourState {
  const MatchCoachTourState({
    this.levelId,
    this.logic,
    this.postWinStep,
    this.started = false,
    this.matchPaused = false,
  });

  final String? levelId;
  final CoachTourSessionLogic? logic;
  final CoachTourStep? postWinStep;
  final bool started;

  /// True while the in-match coach tour is blocking gameplay (independent of
  /// mutated [logic] references so listeners can detect pause/resume).
  final bool matchPaused;

  bool get isActive => levelId != null && logic != null && !(logic!.isComplete);

  bool get showPostWinSpotlight => postWinStep != null;

  MatchCoachTourState copyWith({
    String? levelId,
    CoachTourSessionLogic? logic,
    CoachTourStep? postWinStep,
    bool clearPostWin = false,
    bool? started,
    bool? matchPaused,
  }) {
    return MatchCoachTourState(
      levelId: levelId ?? this.levelId,
      logic: logic ?? this.logic,
      postWinStep: clearPostWin ? null : (postWinStep ?? this.postWinStep),
      started: started ?? this.started,
      matchPaused: matchPaused ?? this.matchPaused,
    );
  }
}

class MatchCoachTourNotifier extends StateNotifier<MatchCoachTourState> {
  MatchCoachTourNotifier(this._ref) : super(const MatchCoachTourState());

  final Ref _ref;

  Future<void> startSession(String levelId) async {
    if (!CoachTourCatalog.isCampaignFtueLevel(levelId)) {
      state = const MatchCoachTourState();
      return;
    }

    final prefs = await _ref.read(ftuePreferencesProvider.future);
    if (!prefs.shouldShowCampaignFtue(levelId)) {
      state = const MatchCoachTourState();
      return;
    }

    if (levelId == 'w1_l03' && !prefs.holdGranted) {
      await _grantHoldIfNeeded();
    }

    final logic = CoachTourSessionLogic(
      tourId: 'campaign_ftue',
      steps: CoachTourCatalog.campaignStepsFor(levelId),
    );

    final showTimer = _ref.read(settingsProvider).showTimer;
    logic.applyConditionalSkips(showTimer: showTimer);

    state = MatchCoachTourState(
      levelId: levelId,
      logic: logic,
      started: true,
      matchPaused: true,
    );

    await AnalyticsService.instance.logCampaignFtueBegin(levelId: levelId);
  }

  Future<void> _grantHoldIfNeeded() async {
    final prefs = await _ref.read(ftuePreferencesProvider.future);
    if (prefs.holdGranted) return;

    final holdCount = _ref
            .read(profileProvider)
            .valueOrNull
            ?.powerUpInventory[PowerUpType.hold.id] ??
        0;
    if (holdCount > 0) {
      await FtuePreferences.markHoldGranted();
      _ref.invalidate(ftuePreferencesProvider);
      return;
    }

    final repo = _ref.read(profileRepositoryProvider);
    await repo.grantPowerUp(PowerUpType.hold.id, 1);
    await FtuePreferences.markHoldGranted();
    _ref.invalidate(ftuePreferencesProvider);
  }

  void onHumanMove(GameState gameState) {
    final logic = state.logic;
    if (logic == null || logic.isComplete) return;
    if (!logic.onHumanMove()) return;
    state = state.copyWith(logic: logic);
    _logStep(logic);
    _maybeCompleteLevel(logic);
  }

  void onHumanBoxClaimed() {
    final logic = state.logic;
    if (logic == null || logic.isComplete) return;
    if (!logic.onHumanBoxClaimed()) return;
    state = state.copyWith(logic: logic);
    _logStep(logic);
  }

  void onHintUsed() {
    final logic = state.logic;
    if (logic == null || logic.isComplete) return;
    if (!logic.onHintUsed()) return;
    state = state.copyWith(logic: logic);
    _logStep(logic);
    _maybeCompleteLevel(logic);
  }

  void onRivalChain() {
    final logic = state.logic;
    if (logic == null || logic.isComplete) return;
    if (!logic.onRivalChain()) return;
    state = state.copyWith(logic: logic);
    _logStep(logic);
  }

  void advanceNext() {
    final logic = state.logic;
    if (logic == null || logic.isComplete) return;
    if (!logic.advanceNext()) return;
    if (logic.isComplete) {
      state = MatchCoachTourState(
        levelId: state.levelId,
        logic: logic,
        started: true,
        matchPaused: false,
      );
    } else {
      state = state.copyWith(logic: logic);
    }
    _logStep(logic);
    _maybeCompleteLevel(logic);
  }

  void dismissCurrentStep() => advanceNext();

  Future<void> skipAll() async {
    final levelId = state.levelId;
    final logic = state.logic;
    if (logic == null || logic.isComplete) return;
    logic.skipAll();
    state = const MatchCoachTourState();
    await FtuePreferences.skipAllCampaignFtue();
    _ref.invalidate(ftuePreferencesProvider);
    await AnalyticsService.instance.logCampaignFtueSkip(
      levelId: levelId ?? 'unknown',
    );
  }

  Future<void> _maybeCompleteLevel(CoachTourSessionLogic logic) async {
    if (!logic.isComplete || state.levelId == null || logic.skipped) return;
    await FtuePreferences.markCampaignLevelComplete(state.levelId!);
    _ref.invalidate(ftuePreferencesProvider);
    await AnalyticsService.instance.logCampaignFtueComplete(skipped: false);
  }

  void showMiniBossPostWinSpotlight() {
    state = state.copyWith(postWinStep: CoachTourCatalog.miniBossPowerUpStep);
  }

  void dismissPostWinSpotlight() {
    state = state.copyWith(clearPostWin: true);
  }

  void _logStep(CoachTourSessionLogic logic) {
    final step = logic.currentStep;
    if (step == null) return;
    AnalyticsService.instance.logCampaignFtueStep(
      levelId: state.levelId ?? 'unknown',
      stepId: step.id,
      stepIndex: logic.stepIndex,
      targetId: step.targetId.name,
    );
  }

  void reset() => state = const MatchCoachTourState();
}

final matchCoachTourProvider = StateNotifierProvider.autoDispose<
    MatchCoachTourNotifier, MatchCoachTourState>(
  MatchCoachTourNotifier.new,
);

// Legacy alias for game_screen imports during migration
final matchTutorialProvider = matchCoachTourProvider;
