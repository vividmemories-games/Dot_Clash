import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/feedback/app_haptics.dart';
import '../../domain/models/game_state.dart';

/// Visual + copy bundle for a campaign boss persona.
class BossPersonaTheme {
  const BossPersonaTheme({
    required this.accent,
    required this.icon,
    required this.portraitAsset,
    required this.taunt,
    required this.introLine,
    required this.subtitle,
  });

  final Color accent;
  final IconData icon;
  final String portraitAsset;
  final String taunt;
  final String introLine;
  final String subtitle;
}

BossPersonaTheme bossPersonaTheme(BossPersona persona, DotClashVisuals v) {
  return switch (persona) {
    BossPersona.machine => const BossPersonaTheme(
        accent: Color(0xFF64B5F6),
        icon: Icons.smart_toy_rounded,
        portraitAsset: 'assets/images/boss_machine.png',
        taunt: 'Perfect lines. Zero mercy.',
        introLine: 'I never misfire. Every line is calculated.',
        subtitle: 'World boss · Relentless logic',
      ),
    BossPersona.trapper => const BossPersonaTheme(
        accent: Color(0xFFCE93D8),
        icon: Icons.grid_on_rounded,
        portraitAsset: 'assets/images/boss_trapper.png',
        taunt: 'Every edge you take is bait.',
        introLine: 'Go ahead — take that edge. I planned for it.',
        subtitle: 'World boss · Patient predator',
      ),
    BossPersona.collector => BossPersonaTheme(
        accent: v.gold,
        icon: Icons.diamond_rounded,
        portraitAsset: 'assets/images/boss_collector.png',
        taunt: 'Claims every box in sight.',
        introLine: 'This grid is mine. Every box. Every corner.',
        subtitle: 'World boss · Greedy chains',
      ),
  };
}

Color bossAccentColor(BossPersona? persona, DotClashVisuals v) {
  return switch (persona) {
    BossPersona.machine => const Color(0xFF64B5F6),
    BossPersona.trapper => const Color(0xFFCE93D8),
    BossPersona.collector => v.gold,
    null => v.red,
  };
}

/// Haptic + system sound punch when a boss intro appears.
Future<void> playBossIntroSting({
  required bool soundEnabled,
  bool hapticsEnabled = true,
}) async {
  if (hapticsEnabled) {
    AppHaptics.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    AppHaptics.mediumImpact();
  }
  if (soundEnabled) {
    SystemSound.play(SystemSoundType.alert);
  }
}
