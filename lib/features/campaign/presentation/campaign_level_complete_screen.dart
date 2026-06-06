import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../features/game/presentation/widgets/boss_persona_theme.dart';
import '../../../features/powerups/domain/power_up.dart';
import '../../../features/powerups/domain/power_up_catalog.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../shared/feedback/app_haptics.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../home/presentation/widgets/resource_pill.dart';
import '../domain/campaign_level.dart';
import 'campaign_play_navigation.dart';
import 'campaign_save_status.dart';
import 'level_result_screen.dart';
import 'widgets/dot_confetti_layer.dart';

/// Full-screen celebration while campaign save runs, then level results.
class CampaignLevelCompleteScreen extends ConsumerStatefulWidget {
  const CampaignLevelCompleteScreen({
    super.key,
    required this.level,
    required this.starsEarned,
    required this.humanWon,
    required this.powerUpRewards,
    required this.saveFuture,
    required this.onRetrySave,
    this.initialCoins = 0,
  });

  final CampaignLevel level;
  final int starsEarned;
  final bool humanWon;
  final Map<String, int> powerUpRewards;
  final Future<void> saveFuture;
  final Future<void> Function() onRetrySave;
  final int initialCoins;

  @override
  ConsumerState<CampaignLevelCompleteScreen> createState() =>
      _CampaignLevelCompleteScreenState();
}

class _CampaignLevelCompleteScreenState
    extends ConsumerState<CampaignLevelCompleteScreen>
    with TickerProviderStateMixin {
  static const _skipDelay = Duration(milliseconds: 800);

  bool _showResults = false;
  bool _skipEnabled = false;
  int _visibleStars = 0;
  bool _confettiActive = false;
  bool _showBossPortrait = false;
  bool _showPowerUps = false;
  bool _coinFlying = false;
  double _coinFlyT = 0;
  int _displayCoins = 0;

  CampaignSaveStatus _saveStatus = CampaignSaveStatus.saving;
  bool _navigatingAway = false;
  String _navigatingMessage = 'Loading next level…';
  late AnimationController _coinCtrl;
  late AnimationController _bossCtrl;
  final List<Timer> _timers = [];

  bool get _isBossWin =>
      widget.humanWon && widget.level.isBoss && widget.level.parsedPersona != null;

  @override
  void initState() {
    super.initState();
    _displayCoins = widget.initialCoins;
    _coinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..addListener(() {
        if (mounted) setState(() => _coinFlyT = _coinCtrl.value);
      });
    _bossCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    widget.saveFuture.then((_) {
      if (mounted) setState(() => _saveStatus = CampaignSaveStatus.saved);
    }).catchError((_) {
      if (mounted) setState(() => _saveStatus = CampaignSaveStatus.failed);
    });

    _timers.add(Timer(_skipDelay, () {
      if (mounted) setState(() => _skipEnabled = true);
    }));

    if (widget.humanWon) {
      _scheduleWinTimeline();
    } else {
      _timers.add(Timer(const Duration(milliseconds: 900), _goToResults));
    }
  }

  void _scheduleWinTimeline() {
    _timers.add(Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      AppHaptics.lightImpact();
    }));

    for (var i = 0; i < 3; i++) {
      final starIndex = i + 1;
      _timers.add(Timer(Duration(milliseconds: 400 + i * 180), () {
        if (!mounted || _showResults) return;
        setState(() {
          _visibleStars = starIndex;
          if (starIndex <= widget.starsEarned) {
            AppHaptics.selectionClick();
          }
          if (starIndex >= 2 && widget.starsEarned >= 2) {
            _confettiActive = true;
          }
        });
      }));
    }

    final coinStartMs = _isBossWin ? 1450 : 950;
    if (_isBossWin) {
      _timers.add(Timer(const Duration(milliseconds: 900), () {
        if (!mounted || _showResults) return;
        setState(() => _showBossPortrait = true);
        _bossCtrl.forward(from: 0);
      }));
      _timers.add(Timer(const Duration(milliseconds: 1200), () {
        if (!mounted || _showResults) return;
        setState(() => _showPowerUps = true);
        AppHaptics.mediumImpact();
      }));
    }

    _timers.add(Timer(Duration(milliseconds: coinStartMs), _startCoinFly));
    _timers.add(Timer(Duration(milliseconds: coinStartMs + 900), _goToResults));
  }

  void _startCoinFly() {
    if (!mounted || _showResults || !widget.humanWon) return;
    setState(() => _coinFlying = true);
    _coinCtrl.forward(from: 0);
    final target = widget.initialCoins + widget.level.coinReward;
    const steps = 12;
    final stepMs = 750 ~/ steps;
    for (var i = 1; i <= steps; i++) {
      _timers.add(Timer(Duration(milliseconds: stepMs * i), () {
        if (!mounted) return;
        setState(() {
          _displayCoins =
              widget.initialCoins +
              ((target - widget.initialCoins) * i / steps).round();
        });
      }));
    }
  }

  void _goToResults() {
    if (!mounted || _showResults) return;
    setState(() {
      _showResults = true;
      _displayCoins = widget.initialCoins + widget.level.coinReward;
    });
  }

  void _skipCelebration() {
    if (!_skipEnabled || _showResults) return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _goToResults();
  }

  Future<void> _leaveToPlayLevel(
    String levelId, {
    required bool replay,
  }) async {
    if (_navigatingAway) return;
    setState(() {
      _navigatingAway = true;
      _navigatingMessage = replay ? 'Restarting level…' : 'Loading next level…';
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (replay) {
      await CampaignPlayNavigation.exitToReplayLevel(context, levelId);
    } else {
      await CampaignPlayNavigation.exitToNextLevel(context, levelId);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _coinCtrl.dispose();
    _bossCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    AppHaptics.configure(
      enabled: ref.watch(settingsProvider).hapticsEnabled,
    );

    return Scaffold(
      backgroundColor: v.scaffold,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _showResults
                  ? LevelResultPanel(
                      key: const ValueKey('results'),
                      level: widget.level,
                      starsEarned: widget.starsEarned,
                      humanWon: widget.humanWon,
                      saveStatus: _saveStatus,
                      onLeaveToPlayLevel: _leaveToPlayLevel,
                      onRetrySave: () async {
                        setState(() => _saveStatus = CampaignSaveStatus.saving);
                        try {
                          await widget.onRetrySave();
                          if (mounted) {
                            setState(() => _saveStatus = CampaignSaveStatus.saved);
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(() => _saveStatus = CampaignSaveStatus.failed);
                          }
                        }
                      },
                    )
                  : _CelebrationLayer(
                      key: const ValueKey('celebration'),
                      level: widget.level,
                      starsEarned: widget.starsEarned,
                      humanWon: widget.humanWon,
                      visibleStars: _visibleStars,
                      confettiActive: _confettiActive,
                      showBossPortrait: _showBossPortrait,
                      showPowerUps: _showPowerUps,
                      powerUpRewards: widget.powerUpRewards,
                      bossCtrl: _bossCtrl,
                      coinFlying: _coinFlying,
                      coinFlyT: _coinFlyT,
                      displayCoins: _displayCoins,
                      skipEnabled: _skipEnabled,
                      onSkip: _skipCelebration,
                    ),
            ),
            if (_saveStatus == CampaignSaveStatus.saving && _showResults)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Syncing progress…',
                    style: context.txt.bodySmall.copyWith(
                      color: v.textSecondary,
                    ),
                  ),
                ),
              ),
            if (_navigatingAway)
              Positioned.fill(
                child: ColoredBox(
                  color: v.scaffold.withValues(alpha: 0.94),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: v.playerA),
                        AppSpacing.vGapMD,
                        Text(
                          _navigatingMessage,
                          style: context.txt.body.copyWith(
                            color: v.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CelebrationLayer extends StatelessWidget {
  const _CelebrationLayer({
    super.key,
    required this.level,
    required this.starsEarned,
    required this.humanWon,
    required this.visibleStars,
    required this.confettiActive,
    required this.showBossPortrait,
    required this.showPowerUps,
    required this.powerUpRewards,
    required this.bossCtrl,
    required this.coinFlying,
    required this.coinFlyT,
    required this.displayCoins,
    required this.skipEnabled,
    required this.onSkip,
  });

  final CampaignLevel level;
  final int starsEarned;
  final bool humanWon;
  final int visibleStars;
  final bool confettiActive;
  final bool showBossPortrait;
  final bool showPowerUps;
  final Map<String, int> powerUpRewards;
  final AnimationController bossCtrl;
  final bool coinFlying;
  final double coinFlyT;
  final int displayCoins;
  final bool skipEnabled;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final size = MediaQuery.sizeOf(context);
    final persona = level.parsedPersona;
    final bossTheme =
        persona != null ? bossPersonaTheme(persona, v) : null;

    return GestureDetector(
      onTap: skipEnabled ? onSkip : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DotConfettiLayer(active: confettiActive),
          Padding(
            padding: AppSpacing.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  humanWon ? 'LEVEL COMPLETE!' : 'OUTPLAYED',
                  style: t.scoreLabel.copyWith(
                    color: humanWon ? v.green : v.red,
                    fontSize: 26,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.vGapSM,
                Text(
                  level.title,
                  style: t.playerName.copyWith(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.vGapLG,
                _AnimatedStarRow(
                  visibleStars: visibleStars,
                  earnedStars: starsEarned,
                  v: v,
                ),
                AppSpacing.vGapLG,
                if (showBossPortrait && bossTheme != null)
                  FadeTransition(
                    opacity: bossCtrl,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            bossTheme.portraitAsset,
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              bossTheme.icon,
                              size: 80,
                              color: bossTheme.accent,
                            ),
                          ),
                        ),
                        AppSpacing.vGapSM,
                        Text(
                          'BOSS DEFEATED',
                          style: t.scoreLabel.copyWith(
                            color: bossTheme.accent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (showPowerUps && powerUpRewards.isNotEmpty) ...[
                  AppSpacing.vGapMD,
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: powerUpRewards.entries.map((entry) {
                      final type = PowerUpTypeX.fromId(entry.key);
                      return _PowerUpRewardChip(
                        type: type,
                        quantity: entry.value,
                        label: type != null
                            ? PowerUpCatalog.labels[type] ?? entry.key
                            : entry.key,
                        accent: type != null
                            ? PowerUpCatalog.accentFor(type, v)
                            : v.gold,
                      );
                    }).toList(),
                  ),
                ],
                if (humanWon && coinFlying) ...[
                  AppSpacing.vGapLG,
                  Text(
                    '+${level.coinReward} coins',
                    style: t.bodySmall.copyWith(
                      color: v.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: AppSpacing.md,
            child: ResourcePill(
              icon: Icons.monetization_on_rounded,
              label: '$displayCoins',
              iconColor: v.gold,
            ),
          ),
          if (coinFlying)
            _FlyingCoin(
              t: coinFlyT,
              screenSize: size,
              color: v.gold,
            ),
          if (skipEnabled)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Tap to skip',
                  style: t.bodySmall.copyWith(color: v.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedStarRow extends StatelessWidget {
  const _AnimatedStarRow({
    required this.visibleStars,
    required this.earnedStars,
    required this.v,
  });

  final int visibleStars;
  final int earnedStars;
  final DotClashVisuals v;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final revealed = i < visibleStars;
        final lit = revealed && i < earnedStars;
        return AnimatedScale(
          scale: revealed ? 1.0 : 0.2,
          duration: const Duration(milliseconds: 280),
          curve: Curves.elasticOut,
          child: AnimatedOpacity(
            opacity: revealed ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                lit ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 52,
                color: lit ? v.gold : v.textDisabled,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PowerUpRewardChip extends StatelessWidget {
  const _PowerUpRewardChip({
    required this.type,
    required this.quantity,
    required this.label,
    required this.accent,
  });

  final PowerUpType? type;
  final int quantity;
  final String label;
  final Color accent;

  IconData get _icon => switch (type) {
        PowerUpType.hold => Icons.pause_circle_outline_rounded,
        PowerUpType.riposte => Icons.replay_rounded,
        PowerUpType.extraTurns => Icons.add_circle_outline_rounded,
        _ => Icons.bolt_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: accent, size: 20),
          const SizedBox(width: 6),
          Text(
            '+$quantity $label',
            style: t.bodySmall.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlyingCoin extends StatelessWidget {
  const _FlyingCoin({
    required this.t,
    required this.screenSize,
    required this.color,
  });

  final double t;
  final Size screenSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final start = Offset(screenSize.width * 0.5, screenSize.height * 0.55);
    final end = Offset(screenSize.width * 0.82, 48);
    final curved = Curves.easeInOut.transform(t);
    final pos = Offset.lerp(start, end, curved)!;
    final scale = 1.0 + (0.35 * (1 - (curved - 0.5).abs() * 2));

    return Positioned(
      left: pos.dx - 14,
      top: pos.dy - 14,
      child: Opacity(
        opacity: (1 - t * 0.15).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Icon(Icons.monetization_on_rounded, color: color, size: 28),
        ),
      ),
    );
  }
}
