import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/feedback/app_haptics.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_tag.dart';
import '../../challenge/data/challenge_repository.dart';
import '../../challenge/domain/challenge_exceptions.dart';
import '../../challenge/providers/challenge_game_provider.dart';
import '../../challenge/providers/challenge_providers.dart';
import '../../campaign/data/campaign_content_repository.dart';
import '../../campaign/domain/campaign_level.dart';
import '../../campaign/domain/campaign_move_metrics.dart';
import '../../campaign/domain/level_evaluator.dart';
import '../../campaign/presentation/campaign_level_complete_screen.dart';
import '../../campaign/providers/campaign_play_ready_provider.dart';
import '../../campaign/presentation/widgets/campaign_objectives_bar.dart';
import '../../../services/analytics/analytics_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../services/ads/ad_reward_router.dart';
import '../../powerups/domain/power_up.dart';
import '../domain/models/game_state.dart';
import '../domain/rules/game_rules.dart';
import '../providers/game_provider.dart';
import '../domain/models/match_session.dart';
import '../providers/match_session_provider.dart';
import 'widgets/board_widget.dart';
import 'widgets/boss_battle_banner.dart';
import 'widgets/boss_intro_overlay.dart';
import 'widgets/boss_persona_theme.dart';
import 'widgets/boost_strip.dart';
import 'widgets/match_more_dock.dart';
import 'widgets/out_of_turns_sheet.dart';
import 'widgets/rescue_offer_sheet.dart';
import 'widgets/score_strip.dart';
import 'widgets/turn_ambient_backdrop.dart';
import 'widgets/turn_countdown_bar.dart';
import '../../powerups/domain/power_up_catalog.dart';
import '../../tutorial/domain/coach_tour_step.dart';
import '../../tutorial/domain/coach_tour_catalog.dart';
import '../../tutorial/presentation/coach_tour_target.dart';
import '../../tutorial/presentation/spotlight_overlay.dart';
import '../../tutorial/providers/coach_tour_provider.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.config});

  final GameConfig config;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  static const _extraTurnsGrant = 3;

  int _hintsLeft = 3;

  /// When set the BoardWidget highlights this edge with a pulsing gold glow.
  String? _hintEdge;

  /// Loaded once for campaign levels to drive the objectives bar.
  CampaignLevel? _campaignLevel;

  /// Boss cinematic intro must finish before the board is playable.
  bool _bossIntroDismissed = true;

  /// First tutorial attempt on w1_l01–w1_l04 skips life cost for that match.
  bool _tutorialFreeAttempt = false;

  /// Deferred campaign settlement after mini-boss post-win spotlight.
  GameState? _pendingSettleState;

  /// Prevents pushing two victory overlays if settlement fires twice.
  bool _campaignResultPushed = false;

  /// True after [gameConfigProvider] matches [widget.config] (Riverpod-safe).
  bool _configSynced = false;

  /// Unique owner for match coach-tour [GlobalKey]s (see [CoachTourGameScope]).
  final Object _gameTourScope = Object();

  bool get _isChallenge => widget.config.mode == GameMode.challenge;

  String? get _challengeCode => widget.config.challengeCode;

  String get _myPlayerId => widget.config.myPlayerId ?? 'A';

  @override
  void initState() {
    super.initState();
    CoachTourTargetRegistry.claimGameScope(_gameTourScope);
    WidgetsBinding.instance.addObserver(this);
    if (widget.config.mode == GameMode.campaign &&
        widget.config.campaignLevelId != null) {
      _bossIntroDismissed = false;
    }
    // Riverpod forbids provider writes in initState; apply after build completes.
    Future(() => _syncGameConfig());
    final campaignLevelId = widget.config.campaignLevelId;
    if (widget.config.mode == GameMode.campaign && campaignLevelId != null) {
      CampaignContentRepository.instance
          .levelById(campaignLevelId)
          .then((level) {
        if (!mounted || level == null) return;
        setState(() {
          _campaignLevel = level;
          _bossIntroDismissed = !level.isBoss;
        });
        if (level.isBoss && level.parsedPersona != null) {
          final theme = bossPersonaTheme(level.parsedPersona!, context.dc);
          precacheImage(AssetImage(theme.portraitAsset), context);
        }
        if (!widget.config.isDailyPuzzle) {
          AnalyticsService.instance.logCampaignLevelStart(
            levelId: level.id,
            worldId: level.worldId,
            levelIndex: level.index,
            isBoss: level.isBoss,
          );
        }
      });
    }
  }

  Future<void> _syncGameConfig() async {
    if (!mounted) return;
    ref.read(gameConfigProvider.notifier).state = widget.config;
    ref.read(adRewardRouterProvider).resetMatchRescueFlag();
    if (!mounted) return;
    setState(() => _configSynced = true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final levelId = widget.config.campaignLevelId;
      final gameState = ref.read(gameProvider);
      if (widget.config.mode == GameMode.campaign &&
          levelId != null &&
          !gameState.isOver) {
        ref.read(campaignPlayReadyProvider.notifier).state = levelId;
      }
      final campaignLevelId = widget.config.campaignLevelId;
      if (widget.config.mode == GameMode.campaign && campaignLevelId != null) {
        _tutorialFreeAttempt = ref.read(
          tutorialFreeAttemptProvider(campaignLevelId),
        );
        await ref.read(matchCoachTourProvider.notifier).startSession(
              campaignLevelId,
            );
      }
      final tourPaused = ref.read(matchCoachTourProvider).matchPaused;
      if (_isChallenge) {
        // Server-synced countdown starts when [challengeTurnTimerProvider] sees
        // `turnStartedAt` on the room snapshot.
      } else if (tourPaused) {
        ref.read(turnTimerProvider.notifier).stop();
      } else if (ref.read(settingsProvider).showTimer) {
        ref.read(turnTimerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_isChallenge) {
        final code = _challengeCode;
        if (code != null) {
          ref.read(challengeTurnTimerProvider(code).notifier).stop();
        }
      } else {
        ref.read(gameProvider.notifier).onAppPaused();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isChallenge) {
        // [challengeTurnTimerProvider] re-syncs from the next room snapshot.
      } else {
        ref.read(gameProvider.notifier).onAppResumed();
      }
    }
  }

  @override
  void deactivate() {
    CoachTourTargetRegistry.releaseGameScope(_gameTourScope);
    // Provider writes are not allowed during deactivate (mid-build).
    final container = ProviderScope.containerOf(context, listen: false);
    Future.microtask(() {
      container.read(turnTimerProvider.notifier).stop();
      container.read(matchCoachTourProvider.notifier).reset();
    });
    super.deactivate();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_configSynced) {
      return Scaffold(
        backgroundColor: context.dc.scaffold,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final state = _isChallenge
        ? ref.watch(challengeGameProvider(_challengeCode!))
        : ref.watch(gameProvider);
    final session = ref.watch(matchSessionProvider);
    final secondsLeft = _isChallenge
        ? ref.watch(challengeTurnTimerProvider(_challengeCode!))
        : ref.watch(turnTimerProvider);
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final inventory = profile?.powerUpInventory ?? const {};
    final showBoosts = !_isChallenge &&
        (widget.config.mode == GameMode.ai ||
            widget.config.mode == GameMode.campaign);

    // When the timer is hidden, disable timed gameplay entirely.
    // - stop the countdown so it doesn't reach 0 in the background
    // - ignore timeout-based turn switching
    ref.listen<SettingsState>(settingsProvider, (prev, next) {
      if (!mounted) return;
      final prevShow = prev?.showTimer ?? next.showTimer;
      if (prevShow == next.showTimer) return;
      if (next.showTimer) {
        ref.read(turnTimerProvider.notifier).reset();
      } else {
        ref.read(turnTimerProvider.notifier).stop();
      }
    });
    if (!_isChallenge && !settings.showTimer) {
      ref.read(turnTimerProvider.notifier).stop();
    }

    final challengeOpponent =
        widget.config.opponentDisplayName ?? 'Rival';
    final playerAName = _scoreboardLabel(switch (widget.config.mode) {
      GameMode.challenge =>
        _myPlayerId == 'A' ? settings.youName : challengeOpponent,
      GameMode.ai || GameMode.campaign => settings.youName,
      GameMode.local => settings.localPlayerAName,
    });
    final bossDisplayName = _campaignLevel?.bossName;
    final playerBName = switch (widget.config.mode) {
      GameMode.challenge =>
        _myPlayerId == 'B' ? settings.youName : challengeOpponent,
      GameMode.ai || GameMode.campaign => (_campaignLevel?.isBoss ?? false)
          ? (bossDisplayName ?? settings.aiName)
          : settings.aiName,
      GameMode.local => settings.localPlayerBName,
    };

    String initialFor(String name, {required String fallback}) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return fallback;
      return trimmed[0].toUpperCase();
    }

    final playerInitials = <String, String>{
      state.playerIds[0]: initialFor(playerAName, fallback: 'A'),
      state.playerIds[1]: initialFor(playerBName, fallback: 'B'),
    };

    // Auto-pass the turn when the timer reaches 0 (local / AI only — server
    // enforces timeouts for challenge matches).
    if (!_isChallenge) {
      ref.listen<int>(turnTimerProvider, (prev, next) {
        if (!mounted) return;
        if (!ref.read(settingsProvider).showTimer) return;
        if (ref.read(matchCoachTourProvider).matchPaused) return;
        final prevVal = prev ?? next;
        if (prevVal > 0 && next == 0) {
          if (mounted) setState(() => _hintEdge = null);
          ref.read(gameProvider.notifier).onTurnTimedOut();
        }
      });
    }

    ref.listen<MatchCoachTourState>(matchCoachTourProvider, (prev, next) {
      if (!mounted) return;
      final wasPaused = prev?.matchPaused ?? false;
      final isPaused = next.matchPaused;

      if (isPaused && !wasPaused) {
        ref.read(turnTimerProvider.notifier).stop();
      } else if (!isPaused && wasPaused) {
        if (ref.read(settingsProvider).showTimer) {
          ref.read(turnTimerProvider.notifier).reset();
        }
      }
    });

    ref.listen<MatchSession>(matchSessionProvider, (prev, next) {
      if (!mounted) return;
      if (next.outOfTurnsPending && !(prev?.outOfTurnsPending ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showOutOfTurnsSheet(context);
        });
      }
      if (next.pendingRiposteOffer && !(prev?.pendingRiposteOffer ?? false)) {
        ref.read(matchCoachTourProvider.notifier).onRivalChain();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showRiposteOffer(context);
        });
      }
    });

    // Tutorial: react to human moves and box captures.
    if (!_isChallenge) {
      ref.listen<GameState>(gameProvider, (prev, next) {
        if (!mounted) return;
        if (prev == null) return;
      final coachState = ref.read(matchCoachTourProvider);
      if (!coachState.isActive) return;

      if (next.moveHistory.length <= prev.moveHistory.length) return;

      final humanId = next.playerIds[0];
      final lastEdge = next.moveHistory.last;
      if (next.edgeOwners[lastEdge] != humanId) return;

      ref.read(matchCoachTourProvider.notifier).onHumanMove(next);

      if (next.claimedCount > prev.claimedCount) {
        for (final entry in next.claimedBoxes.entries) {
          if (prev.claimedBoxes.containsKey(entry.key)) continue;
          if (entry.value == humanId) {
            ref.read(matchCoachTourProvider.notifier).onHumanBoxClaimed();
            break;
          }
        }
      }
      });
    }

    // Show result dialog on game end (challenge settlement uses room status).
    if (!_isChallenge) {
      ref.listen<GameState>(gameProvider, (prev, next) {
        if (!mounted) return;
        if (!next.isOver || (prev?.isOver ?? false)) return;
        setState(() => _hintEdge = null);

        if (widget.config.mode == GameMode.campaign) {
          _settleCampaign(context, ref, next);
        } else {
        final result = next.isTie
            ? MatchResult.tie
            : (next.winnerId == next.playerIds[0]
                ? MatchResult.win
                : MatchResult.loss);
        final repo = ref.read(profileRepositoryProvider);
        repo
            .settleMatch(result, consumeLife: false)
            .catchError((e) => debugPrint('[Profile][settleMatch] failed=$e'));
        final modeLabel =
            widget.config.mode == GameMode.ai ? 'Practice' : 'Local';
        final opponent = widget.config.mode == GameMode.ai
            ? ref.read(settingsProvider).aiName
            : 'Friend';
        repo
            .recordMatch(
              result: result,
              modeLabel: modeLabel,
              opponentLabel: opponent,
            )
            .catchError((e) => debugPrint('[Profile][recordMatch] failed=$e'));
        if (widget.config.mode == GameMode.ai) {
          final removeAds =
              ref.read(profileProvider).valueOrNull?.removeAds ?? false;
          unawaited(ref.read(adRewardRouterProvider).handleMatchFinished(
                removeAds: removeAds,
              ));
        }
        _showResultDialog(context, next);
        }
      });
    }

    final isVsAi = widget.config.mode == GameMode.ai ||
        widget.config.mode == GameMode.campaign;
    final isAiTurn = isVsAi && state.currentPlayerId == state.playerIds[1];
    final isOpponentTurn =
        _isChallenge && state.currentPlayerId != _myPlayerId;
    final humanTurnReady =
        _isChallenge ? true : ref.watch(humanTurnReadyProvider);
    final opponentHighlightEdge = (isVsAi || _isChallenge)
        ? ref.watch(opponentLastEdgeProvider)
        : null;

    final coachTourState = ref.watch(matchCoachTourProvider);
    final coachLogic = coachTourState.logic;
    final coachStep = coachTourState.postWinStep ?? coachLogic?.currentStep;
    final coachTourActive =
        coachTourState.isActive || coachTourState.showPostWinSpotlight;
    final coachBlocksInteraction = coachLogic?.blocksInteraction ?? false;
    final coachAllowedEdges = coachLogic?.allowedEdges(state);
    final coachHintEdge = coachLogic?.highlightEdge(state);
    final effectiveHintEdge = coachHintEdge ?? _hintEdge;

    final coachPausesMatch = coachTourState.matchPaused;
    final coachAllowsBoard = coachPausesMatch &&
        coachStep?.advanceOn == CoachAdvanceTrigger.humanMove;
    final coachAllowsHint = coachPausesMatch &&
        coachStep?.advanceOn == CoachAdvanceTrigger.hintUsed;
    final coachAllowsHold = coachPausesMatch &&
        coachStep?.advanceOn == CoachAdvanceTrigger.tapTarget &&
        coachStep?.targetId == CoachTourTargetId.gamePowerUpHold;

    final canInteract = !state.isOver &&
        !isAiTurn &&
        !isOpponentTurn &&
        humanTurnReady &&
        !session.outOfTurnsPending &&
        _bossIntroDismissed &&
        !coachBlocksInteraction &&
        (!coachPausesMatch || coachAllowsBoard);

    final boostEnabled = canInteract || coachAllowsHint || coachAllowsHold;

    final humanPlayerId =
        _isChallenge ? _myPlayerId : state.playerIds[0];
    // Count human TURNS (chains = 1 turn, not every line drawn).
    final humanTurnCount =
        CampaignMoveMetrics.humanTurnCount(state, humanPlayerId);

    AppHaptics.configure(enabled: settings.hapticsEnabled);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final compactLayout = screenHeight < 700;
    final v = context.dc;
    final isBossFight = _campaignLevel?.isBoss ?? false;
    final bossPersona =
        _campaignLevel?.parsedPersona ?? widget.config.bossPersona;
    final bossAccent = bossAccentColor(bossPersona, v);
    final showBossIntro =
        isBossFight && bossPersona != null && !_bossIntroDismissed;

    final scoreA = _compactScoreboardName(playerAName);
    final scoreB = _compactScoreboardName(playerBName);
    final isCampaign =
        widget.config.mode == GameMode.campaign && _campaignLevel != null;

    final sectionGap = compactLayout ? 2.0 : 4.0;

    Widget body = Column(
      children: [
        _buildHeader(context),
        SizedBox(height: sectionGap),
        CoachTourTarget(
          id: CoachTourTargetId.gameScoreStrip,
          child: ScoreStrip(
            state: state,
            playerALabel: scoreA,
            playerBLabel: scoreB,
            playerAInitial: playerInitials[state.playerIds[0]],
            playerBInitial: playerInitials[state.playerIds[1]],
            opponentIsBoss: isBossFight,
            bossAccentColor: bossAccent,
            showTimer: settings.showTimer || _isChallenge,
            secondsLeft: secondsLeft,
            isLocalMode: widget.config.mode == GameMode.local,
            localPlayerId: _isChallenge ? _myPlayerId : state.playerIds[0],
          ),
        ),
        SizedBox(height: sectionGap),
        TurnCountdownBar(session: session),
        if (session.hasTurnBudget) SizedBox(height: sectionGap),
        if (isCampaign) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: CoachTourTarget(
              id: CoachTourTargetId.gameObjectivesBar,
              child: CampaignObjectivesBar(
                level: _campaignLevel!,
                humanScore: state.scoreOf(humanPlayerId),
                aiScore: state.scoreOf(state.playerIds[1]),
                humanTurnsUsed: humanTurnCount,
                isOver: state.isOver,
                humanWon: state.winnerId == humanPlayerId,
              ),
            ),
          ),
          SizedBox(height: sectionGap),
        ],
        if (widget.config.mode != GameMode.campaign) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: NeonTag(
              label: 'Target: ${state.totalBoxes} boxes',
              icon: Icons.emoji_events_outlined,
              color: v.gold,
            ),
          ),
          SizedBox(height: sectionGap),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: CoachTourTarget(
              id: CoachTourTargetId.gameBoard,
              child: BoardWidget(
                state: state,
                isInteractive: canInteract,
                hintEdge: effectiveHintEdge,
                opponentHighlightEdge: opponentHighlightEdge,
                playerInitials: playerInitials,
                onEdgeTap: (edge) {
                  if (coachAllowedEdges != null &&
                      !coachAllowedEdges.contains(edge)) {
                    AppHaptics.lightImpact();
                    return;
                  }
                  AppHaptics.mediumImpact();
                  if (_hintEdge != null && coachHintEdge == null) {
                    setState(() => _hintEdge = null);
                  }
                  if (_isChallenge) {
                    unawaited(_submitChallengeMove(edge));
                  } else {
                    ref.read(gameProvider.notifier).makeMove(edge);
                  }
                },
              ),
            ),
          ),
        ),
        if (showBoosts) ...[
          const SizedBox(height: 4),
          CoachTourTarget(
            id: CoachTourTargetId.gamePowerUpPanel,
            child: PowerUpPanel(
              session: session,
              inventory: inventory,
              enabled: boostEnabled && state.currentPlayerId == humanPlayerId,
              onBoostTap: _onBoostTap,
              onHint: _onHint,
              hintsLeft: _hintsLeft,
              hintEnabled:
                  boostEnabled && state.currentPlayerId == humanPlayerId,
            ),
          ),
        ] else ...[
          const SizedBox(height: 4),
          HintGradientButton(
            hintsLeft: _hintsLeft,
            enabled: !state.isOver &&
                state.currentPlayerId == humanPlayerId &&
                _hintsLeft > 0,
            onTap: _onHint,
          ),
        ],
        MatchMoreDock(
          canUndo:
              !_isChallenge && state.moveHistory.isNotEmpty && !state.isOver,
          onUndo: _onUndo,
          onRestart: _isChallenge
              ? () {}
              : () => _confirmNewGame(context),
          onExit: () => _requestLeaveGame(
            context,
            navigate: () => context.go(
              _isChallenge ? AppRoutes.home : '/home',
            ),
          ),
          extraTurnsAvailable: showBoosts &&
              session.hasTurnBudget &&
              !session.extraTurnsUsed &&
              (inventory[PowerUpType.extraTurns.id] ?? 0) > 0,
          onExtraTurns:
              showBoosts ? () => _onBoostTap(PowerUpType.extraTurns) : null,
        ),
      ],
    );

    final isHumanTurn = state.currentPlayerId == humanPlayerId;
    final opponentAmbientColor = switch (widget.config.mode) {
      GameMode.challenge || GameMode.local => v.playerB,
      GameMode.ai || GameMode.campaign => isBossFight ? bossAccent : v.playerB,
    };

    body = TurnAmbientBackdrop(
      isHumanTurn: isHumanTurn,
      humanColor: v.playerA,
      opponentColor: opponentAmbientColor,
      enabled: !state.isOver,
      child: body,
    );

    if (isBossFight) {
      body = BossArenaBackground(
        persona: bossPersona,
        personaAccent: bossAccent,
        child: body,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(
          _requestLeaveGame(
            context,
            navigate: () => context.go('/home'),
          ),
        );
      },
      child: CoachTourGameScope(
        owner: _gameTourScope,
        child: Scaffold(
          backgroundColor: v.scaffold,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                body,
                if (showBossIntro)
                  BossIntroOverlay(
                    bossName: _campaignLevel?.bossName ?? playerBName,
                    persona: bossPersona,
                    isMiniBoss: (_campaignLevel?.index ?? 0) == 5,
                    soundEnabled: settings.soundEnabled,
                    hapticsEnabled: settings.hapticsEnabled,
                    onBegin: () => setState(() => _bossIntroDismissed = true),
                  ),
                if (coachTourActive && coachStep != null)
                  ..._buildCoachTourOverlays(
                    step: coachStep,
                    logic: coachLogic,
                    isPostWin: coachTourState.showPostWinSpotlight,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldConfirmLeave(GameState state) =>
      state.moveHistory.isNotEmpty && !state.isOver;

  Future<void> _submitChallengeMove(String edge) async {
    final code = _challengeCode;
    if (code == null) return;
    try {
      await ref.read(challengeGameProvider(code).notifier).makeMove(edge);
    } on ChallengeException catch (e) {
      if (mounted) AppSnackBar.show(context, e.message);
    }
  }

  Future<void> _requestLeaveGame(
    BuildContext context, {
    required void Function() navigate,
  }) async {
    final state = _isChallenge
        ? ref.read(challengeGameProvider(_challengeCode!))
        : ref.read(gameProvider);
    if (!_shouldConfirmLeave(state)) {
      await _leaveGameRoute(navigate);
      return;
    }

    final isCampaign = widget.config.mode == GameMode.campaign;
    final isChallenge = _isChallenge;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final v = ctx.dc;
        return AlertDialog(
          title: Text(switch ((isCampaign, isChallenge)) {
            (true, _) => 'Leave this level?',
            (_, true) => 'Leave challenge?',
            _ => 'Leave match?',
          }),
          content: Text(
            switch ((isCampaign, isChallenge)) {
              (true, _) =>
                'Your progress on this level will be lost. '
                    'Your life won\'t be used — you can try again from the map.',
              (_, true) =>
                'Leaving forfeits the match. Your opponent may win.',
              _ => 'Your current game progress will be lost.',
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: v.red),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      await _leaveGameRoute(navigate);
    }
  }

  Future<void> _leaveGameRoute(void Function() navigate) async {
    if (_isChallenge) {
      final code = _challengeCode;
      final state = ref.read(challengeGameProvider(code!));
      if (state.moveHistory.isNotEmpty && !state.isOver) {
        try {
          await ref.read(challengeRepositoryProvider).abandonChallenge(code);
        } catch (e) {
          debugPrint('[Challenge][abandon] failed=$e');
        }
      }
    }
    CoachTourTargetRegistry.releaseAllGameTargets();
    navigate();
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.home_outlined,
            onTap: () {
              AppHaptics.lightImpact();
              _requestLeaveGame(
                context,
                navigate: () => context.go('/home'),
              );
            },
          ),
          Expanded(child: _buildTitle()),
          _HeaderIconButton(
            icon: Icons.settings_outlined,
            onTap: () {
              AppHaptics.lightImpact();
              context.push('/settings');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Builder(builder: (context) {
      final v = context.dc;
      final t = context.txt;
      final level = _campaignLevel;

      if (widget.config.mode == GameMode.campaign) {
        if (level == null) {
          return Center(
            child: Text(
              'Dot Clash',
              style: t.gameTitle.copyWith(fontSize: 15, letterSpacing: 0.4),
            ),
          );
        }
        final isBoss = level.isBoss;
        final persona = level.parsedPersona;
        final accent = isBoss ? bossAccentColor(persona, v) : v.textPrimary;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Level ${level.index}',
                style: t.scoreLabel.copyWith(
                  fontSize: 10,
                  color: v.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                level.title,
                style: t.gameTitle.copyWith(
                  fontSize: isBoss ? 14 : 15,
                  color: accent,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      final subtitle =
          switch ((widget.config.mode, widget.config.isDailyPuzzle)) {
        (GameMode.challenge, _) => 'Challenge',
        (GameMode.ai, true) => 'Daily puzzle',
        (GameMode.ai, false) => 'Practice',
        (GameMode.local, _) => 'Local match',
        _ => null,
      };

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dot Clash',
              style: t.gameTitle.copyWith(
                fontSize: 15,
                letterSpacing: 0.4,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: t.scoreLabel.copyWith(
                  fontSize: 10,
                  color: v.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  String _scoreboardLabel(String raw, {String fallback = 'You'}) {
    final name = raw.trim();
    if (name.isEmpty) return fallback;
    if (name.length > 14 || RegExp(r'^[A-Za-z0-9]{18,}$').hasMatch(name)) {
      return fallback;
    }
    return name;
  }

  /// Short label for the compact score strip (all game modes).
  String _compactScoreboardName(String raw, {String fallback = 'You'}) {
    final name = _scoreboardLabel(raw, fallback: fallback);
    if (name.length <= 12) return name;
    final first = name.split(RegExp(r'\s+')).first;
    if (first.isNotEmpty && first.length <= 12) return first;
    return '${name.substring(0, 11)}…';
  }

  // ── Boosts & crisis modals ─────────────────────────────────────────────────

  void _showBoostMessage(String message) {
    if (!mounted) return;
    AppSnackBar.show(context, message);
  }

  Future<void> _onBoostTap(PowerUpType type) async {
    final repo = ref.read(profileRepositoryProvider);
    final game = ref.read(gameProvider.notifier);
    final session = ref.read(matchSessionProvider);
    final state = ref.read(gameProvider);
    final humanId = state.playerIds[0];
    final inventory =
        ref.read(profileProvider).valueOrNull?.powerUpInventory ?? const {};

    if (type == PowerUpType.hold) {
      if (session.holdUsed) {
        _showBoostMessage('Hold already used this match.');
        return;
      }
      if ((inventory[PowerUpType.hold.id] ?? 0) <= 0) {
        _showBoostMessage('No Hold boosts in inventory.');
        return;
      }
      if (state.currentPlayerId != humanId) {
        _showBoostMessage('Use Hold on your turn.');
        return;
      }
      final applied = await game.useHold();
      if (!applied) {
        _showBoostMessage('Hold could not be used right now.');
        return;
      }
      final consumed = await repo.consumePowerUp(PowerUpType.hold.id);
      if (!consumed) {
        game.revertHold();
        _showBoostMessage('Could not use Hold. Try again.');
        return;
      }
      ref.read(matchCoachTourProvider.notifier).advanceNext();
      _showBoostMessage('Hold active — rival\'s next turn skipped.');
      return;
    }

    if (type == PowerUpType.riposte) {
      if (session.riposteUsed) return;
      final applied = await game.useRiposte();
      if (!applied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Riposte needs a recent rival combo to undo.'),
            ),
          );
        }
        return;
      }
      await repo.consumePowerUp(PowerUpType.riposte.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Riposte! Rival combo undone.')),
        );
      }
      return;
    }

    if (type == PowerUpType.extraTurns) {
      if (session.extraTurnsUsed || !session.hasTurnBudget) return;
      if ((inventory[PowerUpType.extraTurns.id] ?? 0) <= 0) {
        _showBoostMessage('No Extra Turns boosts in inventory.');
        return;
      }
      final consumed = await repo.consumePowerUp(PowerUpType.extraTurns.id);
      if (!consumed) {
        _showBoostMessage('Could not use Extra Turns. Try again.');
        return;
      }
      game.addTurnsFromBoost(_extraTurnsGrant);
      _showBoostMessage('+$_extraTurnsGrant turns added.');
    }
  }

  Future<void> _showOutOfTurnsSheet(BuildContext context) async {
    final v = context.dc;
    final router = ref.read(adRewardRouterProvider);
    final session = ref.read(matchSessionProvider);
    final inventory =
        ref.read(profileProvider).valueOrNull?.powerUpInventory ?? const {};

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: v.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: v.cardBorder),
      ),
      builder: (_) => OutOfTurnsSheet(
        canWatchAd: router.canOfferRescueAd,
        hasExtraTurnBoost: !session.extraTurnsUsed &&
            (inventory[PowerUpType.extraTurns.id] ?? 0) > 0,
        onWatchAd: () async {
          final ok = await router.showRewardedExtraTurns(grantInventory: false);
          if (ok) {
            ref.read(gameProvider.notifier).addTurnsFromBoost(_extraTurnsGrant);
          }
        },
        onUseBoost: () => _onBoostTap(PowerUpType.extraTurns),
        onGiveUp: () => ref.read(gameProvider.notifier).finalizeOutOfTurns(),
      ),
    );
  }

  Future<void> _showRiposteOffer(BuildContext context) async {
    final v = context.dc;
    final router = ref.read(adRewardRouterProvider);
    final inventory =
        ref.read(profileProvider).valueOrNull?.powerUpInventory ?? const {};
    final hasRiposte = (inventory[PowerUpType.riposte.id] ?? 0) > 0;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: v.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: v.cardBorder),
      ),
      builder: (_) => RescueOfferSheet(
        title: 'Rival chain!',
        message:
            'The rival captured 3+ boxes in a row. Watch the ad or tap Riposte '
            'below to undo their entire combo.',
        inventoryAccentColor: PowerUpCatalog.accentFor(PowerUpType.riposte, v),
        canWatchAd: router.canOfferRescueAd && !hasRiposte,
        hasInventory: hasRiposte,
        inventoryLabel: 'Use Riposte',
        adLabel: 'Watch ad · Riposte',
        onWatchAd: () async {
          final ok = await router.showRewardedRiposte();
          if (ok) {
            await _onBoostTap(PowerUpType.riposte);
          }
        },
        onUseInventory: () => _onBoostTap(PowerUpType.riposte),
        onDismiss: () => ref.read(gameProvider.notifier).clearRiposteOffer(),
      ),
    );
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

  void _onUndo() {
    AppHaptics.mediumImpact();
    setState(() => _hintEdge = null);
    ref.read(gameProvider.notifier).undo();
    ref.read(turnTimerProvider.notifier).reset();
  }

  // ── Hint ───────────────────────────────────────────────────────────────────

  void _onHint() {
    if (_hintsLeft <= 0) return;
    final state = ref.read(gameProvider);
    if (state.isOver) return;

    final moves = GameRules.legalMoves(state);
    if (moves.isEmpty) return;

    // Prefer a move that completes a box; otherwise the safest move.
    String? suggested;
    for (final m in moves) {
      if (GameRules.applyMove(state, m).claimedCount > state.claimedCount) {
        suggested = m;
        break;
      }
    }
    suggested ??= moves.first;

    setState(() {
      _hintsLeft--;
      _hintEdge = suggested;
    });
    ref.read(matchCoachTourProvider.notifier).onHintUsed();

    // Auto-clear hint after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _hintEdge == suggested) {
        setState(() => _hintEdge = null);
      }
    });

    AppHaptics.lightImpact();
  }

  // ── New game ───────────────────────────────────────────────────────────────

  Future<void> _confirmNewGame(BuildContext context) async {
    // If the game hasn't started, just reset without asking.
    final state = ref.read(gameProvider);
    if (state.moveHistory.isEmpty) {
      _resetGame();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Game?'),
        content: const Text('Your current progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _resetGame();
  }

  void _resetGame() {
    setState(() {
      _hintsLeft = 3;
      _hintEdge = null;
    });
    ref.read(gameProvider.notifier).newGame();
    ref.read(turnTimerProvider.notifier).reset();
  }

  // ── Campaign settlement ────────────────────────────────────────────────────

  void _settleCampaign(
      BuildContext context, WidgetRef ref, GameState state) async {
    final levelId = widget.config.campaignLevelId;
    if (levelId == null) return;

    final level = _campaignLevel ??
        await CampaignContentRepository.instance.levelById(levelId);
    if (level == null) return;

    final humanId = state.playerIds[0];
    final humanWon = state.winnerId == humanId;

    if (humanWon &&
        level.isBoss &&
        level.index == 5 &&
        !ref.read(matchCoachTourProvider).showPostWinSpotlight) {
      final rewards = level.powerUpRewards.isNotEmpty
          ? level.powerUpRewards
          : CampaignLevel.defaultBossPowerUpRewards(level);
      if (rewards.isNotEmpty) {
        ref
            .read(matchCoachTourProvider.notifier)
            .showMiniBossPostWinSpotlight();
        setState(() => _pendingSettleState = state);
        return;
      }
    }

    await _pushCampaignCompleteScreen(context, ref, state, level);
  }

  Future<void> _pushCampaignCompleteScreen(
    BuildContext context,
    WidgetRef ref,
    GameState state,
    CampaignLevel level,
  ) async {
    if (_campaignResultPushed) return;
    _campaignResultPushed = true;

    final levelId = level.id;
    final humanId = state.playerIds[0];
    final humanWon = state.winnerId == humanId;
    final boxesCaptured = state.scores[humanId] ?? 0;
    final repo = ref.read(profileRepositoryProvider);
    final initialCoins = ref.read(profileProvider).valueOrNull?.coins ?? 0;
    final removeAds = ref.read(profileProvider).valueOrNull?.removeAds ?? false;
    final adRewardRouter = ref.read(adRewardRouterProvider);
    final consumeLifeOnLoss = !_tutorialFreeAttempt;

    if (widget.config.isDailyPuzzle) {
      if (humanWon) {
        unawaited(
          repo
              .settleDailyPuzzle(
                levelId: levelId,
                win: true,
                boxesCaptured: boxesCaptured,
              )
              .catchError((e) => debugPrint('[Daily][settle] failed=$e')),
        );
      }
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:
              Text(humanWon ? 'Daily puzzle complete!' : 'Try again tomorrow'),
          content: Text(
            humanWon
                ? '+50 coins · Streak updated'
                : 'The daily board resets at midnight UTC.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (context.mounted) context.pop();
      return;
    }

    final payload = MatchPayload(finalState: state, humanPlayerId: humanId);
    final stars = humanWon ? LevelEvaluator.evaluate(level, payload) : 0;
    final powerUpRewards = humanWon
        ? (level.powerUpRewards.isNotEmpty
            ? level.powerUpRewards
            : CampaignLevel.defaultBossPowerUpRewards(level))
        : const <String, int>{};

    Future<void> runSave() async {
      try {
        await repo.settleCampaignLevel(
          levelId: levelId,
          starsEarned: stars,
          coinReward: level.coinReward,
          xpReward: level.xpReward,
          win: humanWon,
          boxesCaptured: boxesCaptured,
          powerUpRewards: powerUpRewards,
          consumeLife: consumeLifeOnLoss,
        );
        await repo.recordMatch(
          result: humanWon ? MatchResult.win : MatchResult.loss,
          modeLabel: 'Campaign',
          opponentLabel: level.isBoss ? (level.bossName ?? 'Boss') : 'Rival',
        );
        AnalyticsService.instance.logCampaignLevelComplete(
          levelId: levelId,
          worldId: level.worldId,
          levelIndex: level.index,
          starsEarned: stars,
          isBoss: level.isBoss,
          humanWon: humanWon,
        );
        if (!CoachTourCatalog.isCampaignFtueLevel(levelId)) {
          unawaited(adRewardRouter.handleMatchFinished(removeAds: removeAds));
        }
      } catch (e, st) {
        await AnalyticsService.instance.recordError(e, st);
        rethrow;
      }
    }

    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CampaignLevelCompleteScreen(
          level: level,
          starsEarned: stars,
          humanWon: humanWon,
          powerUpRewards: powerUpRewards,
          initialCoins: initialCoins,
          saveFuture: runSave(),
          onRetrySave: runSave,
        ),
      ),
    );
  }

  // ── Result dialog ──────────────────────────────────────────────────────────

  void _showResultDialog(BuildContext context, GameState state) {
    final v = context.dc;
    final ids = state.playerIds;

    final String headline;
    final String subline;
    final Color color;
    final IconData icon;

    if (state.isTie) {
      headline = "It's a Tie!";
      subline = 'Perfectly matched.';
      color = v.gold;
      icon = Icons.handshake_outlined;
    } else if (state.winnerId == ids[0]) {
      headline = '${_labelA()} Wins!';
      subline = 'Impressive!';
      color = v.playerA;
      icon = Icons.emoji_events_rounded;
    } else {
      headline = '${_labelB()} Wins!';
      subline = (widget.config.mode == GameMode.ai ||
              widget.config.mode == GameMode.campaign)
          ? 'The machine wins this round.'
          : 'Well played!';
      color = v.playerB;
      icon = Icons.emoji_events_rounded;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _ResultDialog(
        headline: headline,
        subline: subline,
        icon: icon,
        color: color,
        scoreA: state.scoreOf(ids[0]),
        scoreB: state.scoreOf(ids[1]),
        labelA: _labelA(),
        labelB: _labelB(),
        onHome: () {
          Navigator.pop(context);
          _leaveGameRoute(() => context.go('/home'));
        },
        onPlayAgain: () {
          Navigator.pop(context);
          _resetGame();
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _labelA() {
    if (widget.config.mode == GameMode.local) return 'Player A';
    return ref.read(settingsProvider).youName;
  }

  String _labelB() {
    if (widget.config.mode == GameMode.local) return 'Player B';
    if (widget.config.mode == GameMode.campaign) {
      final boss = _campaignLevel?.bossName;
      if ((_campaignLevel?.isBoss ?? false) &&
          boss != null &&
          boss.isNotEmpty) {
        return boss;
      }
    }
    return ref.read(settingsProvider).aiName;
  }

  List<Widget> _buildCoachTourOverlays({
    required CoachTourStep step,
    CoachTourSessionLogic? logic,
    required bool isPostWin,
  }) {
    Future<void> finishPostWin() async {
      ref.read(matchCoachTourProvider.notifier).dismissPostWinSpotlight();
      final pending = _pendingSettleState;
      if (pending == null) return;
      _pendingSettleState = null;
      final level = _campaignLevel ??
          await CampaignContentRepository.instance
              .levelById(widget.config.campaignLevelId ?? '');
      if (!mounted || level == null) return;
      await _pushCampaignCompleteScreen(context, ref, pending, level);
    }

    return [
      SpotlightOverlay(
        step: step,
        stepIndex: isPostWin ? 0 : (logic?.stepIndex ?? 0),
        totalSteps: isPostWin ? 1 : (logic?.steps.length ?? 1),
        showSkip: isPostWin ? step.showSkip : (logic?.showSkipButton ?? false),
        onNext: () {
          if (isPostWin) {
            unawaited(finishPostWin());
          } else {
            ref.read(matchCoachTourProvider.notifier).advanceNext();
          }
        },
        onSkip: () {
          if (isPostWin) {
            unawaited(finishPostWin());
          } else {
            unawaited(ref.read(matchCoachTourProvider.notifier).skipAll());
          }
        },
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header icon button
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: v.surface,
          shape: BoxShape.circle,
          border: Border.all(color: v.cardBorder),
        ),
        child: Icon(icon, color: v.textPrimary, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({
    required this.headline,
    required this.subline,
    required this.icon,
    required this.color,
    required this.scoreA,
    required this.scoreB,
    required this.labelA,
    required this.labelB,
    required this.onHome,
    required this.onPlayAgain,
  });

  final String headline;
  final String subline;
  final IconData icon;
  final Color color;
  final int scoreA;
  final int scoreB;
  final String labelA;
  final String labelB;
  final VoidCallback onHome;
  final VoidCallback onPlayAgain;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: v.surface,
              borderRadius: AppSpacing.roundedXL,
              border: Border.all(
                color: widget.color.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: v.useGlow
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.12),
                    border: Border.all(
                        color: widget.color.withOpacity(0.4), width: 1.5),
                    boxShadow: v.useGlow
                        ? [
                            BoxShadow(
                              color: widget.color.withOpacity(0.35),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.headline,
                  style: t.heroTitle.copyWith(
                    color: widget.color,
                    fontSize: 26,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subline,
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScoreBadge(
                      label: widget.labelA,
                      score: widget.scoreA,
                      color: v.playerA,
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text('–',
                          style: t.heroTitle
                              .copyWith(color: v.textSecondary, fontSize: 20)),
                    ),
                    _ScoreBadge(
                      label: widget.labelB,
                      score: widget.scoreB,
                      color: v.playerB,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onHome,
                        child: const Text('Home'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: widget.color),
                        onPressed: widget.onPlayAgain,
                        child: const Text('Play Again'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$score',
          style: t.scoreNumber.copyWith(
            fontSize: 36,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: t.scoreLabel.copyWith(color: color),
        ),
      ],
    );
  }
}
