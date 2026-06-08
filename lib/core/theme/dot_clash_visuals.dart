import 'package:flutter/material.dart';

/// Runtime palette consumed by every Dot Clash screen and widget.
///
/// Neon arena palettes are selected via equipped shop theme id.
/// Widgets should read these via [BuildContext.dc] instead of hard-coding colors.
@immutable
class DotClashVisuals extends ThemeExtension<DotClashVisuals> {
  const DotClashVisuals({
    required this.useGlow,
    required this.scaffold,
    required this.backgroundGradientTop,
    required this.surface,
    required this.surfaceElevated,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.playerA,
    required this.playerADark,
    required this.playerAGlow,
    required this.playerAFill,
    required this.playerB,
    required this.playerBDark,
    required this.playerBGlow,
    required this.playerBFill,
    required this.gold,
    required this.green,
    required this.red,
    required this.onAccent,
    required this.vsText,
    required this.dotActive,
    required this.dotGlow,
    required this.edgeInactive,
    required this.edgeHover,
    required this.boardSurface,
    required this.boardGlow,
    required this.undoColor,
    required this.hintColor,
    required this.newGameColor,
  });

  final bool useGlow;

  final Color scaffold;
  final Color backgroundGradientTop;
  final Color surface;
  final Color surfaceElevated;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color playerA;
  final Color playerADark;
  final Color playerAGlow;
  final Color playerAFill;
  final Color playerB;
  final Color playerBDark;
  final Color playerBGlow;
  final Color playerBFill;
  final Color gold;
  final Color green;
  final Color red;
  final Color onAccent;
  final Color vsText;
  final Color dotActive;
  final Color dotGlow;
  final Color edgeInactive;
  final Color edgeHover;

  /// Playfield fill — kept in sync with [scaffold] so the grid matches the screen.
  final Color boardSurface;
  final Color boardGlow;
  final Color undoColor;
  final Color hintColor;
  final Color newGameColor;

  Color playerColor(String playerId) => playerId == 'A' ? playerA : playerB;
  Color playerGlowOf(String playerId) =>
      playerId == 'A' ? playerAGlow : playerBGlow;
  Color playerFillOf(String playerId) =>
      playerId == 'A' ? playerAFill : playerBFill;

  static const DotClashVisuals neon = DotClashVisuals(
    useGlow: true,
    scaffold: Color(0xFF101A28),
    backgroundGradientTop: Color(0xFF152A42),
    surface: Color(0xFF152232),
    surfaceElevated: Color(0xFF1A2D45),
    cardBorder: Color(0xFF2A4A72),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA3B4D4),
    textDisabled: Color(0xFF3A4D6B),
    playerA: Color(0xFF00D4FF),
    playerADark: Color(0xFF0090B8),
    playerAGlow: Color(0x5500D4FF),
    playerAFill: Color(0x2200D4FF),
    playerB: Color(0xFFFF2EFF),
    playerBDark: Color(0xFFB800B8),
    playerBGlow: Color(0x55FF2EFF),
    playerBFill: Color(0x22FF2EFF),
    gold: Color(0xFFFFB830),
    green: Color(0xFF00E676),
    red: Color(0xFFFF4C4C),
    onAccent: Color(0xFFFFFFFF),
    vsText: Color(0xFFAACCEE),
    dotActive: Color(0xFFFFFFFF),
    dotGlow: Color(0x88FFFFFF),
    edgeInactive: Color(0x33FFFFFF),
    edgeHover: Color(0x55FFFFFF),
    boardSurface: Color(0xFF101A28),
    boardGlow: Color(0xFF2A4A72),
    undoColor: Color(0xFFFFB830),
    hintColor: Color(0xFFFFEB3B),
    newGameColor: Color(0xFF00E676),
  );

  static const DotClashVisuals ember = DotClashVisuals(
    useGlow: true,
    scaffold: Color(0xFF120B08),
    backgroundGradientTop: Color(0xFF28160F),
    surface: Color(0xFF1A110D),
    surfaceElevated: Color(0xFF24160F),
    cardBorder: Color(0xFF5A3320),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCAA185),
    textDisabled: Color(0xFF6D4A36),
    playerA: Color(0xFFFFB830),
    playerADark: Color(0xFFCC7C00),
    playerAGlow: Color(0x66FFB830),
    playerAFill: Color(0x22FFB830),
    playerB: Color(0xFFFF4C4C),
    playerBDark: Color(0xFFC62828),
    playerBGlow: Color(0x66FF4C4C),
    playerBFill: Color(0x22FF4C4C),
    gold: Color(0xFFFFD166),
    green: Color(0xFF5FD58B),
    red: Color(0xFFFF4C4C),
    onAccent: Color(0xFFFFFFFF),
    vsText: Color(0xFFFFD5B5),
    dotActive: Color(0xFFFFF3E6),
    dotGlow: Color(0x88FFF3E6),
    edgeInactive: Color(0x33FFE0C7),
    edgeHover: Color(0x66FFD1A3),
    boardSurface: Color(0xFF120B08),
    boardGlow: Color(0xFF5A3320),
    undoColor: Color(0xFFFFB830),
    hintColor: Color(0xFFFFD166),
    newGameColor: Color(0xFF5FD58B),
  );

  static const DotClashVisuals mint = DotClashVisuals(
    useGlow: true,
    scaffold: Color(0xFF051114),
    backgroundGradientTop: Color(0xFF0A252B),
    surface: Color(0xFF0A1B20),
    surfaceElevated: Color(0xFF10262D),
    cardBorder: Color(0xFF1A4A55),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8EB7C0),
    textDisabled: Color(0xFF365560),
    playerA: Color(0xFF00E676),
    playerADark: Color(0xFF00AA54),
    playerAGlow: Color(0x6600E676),
    playerAFill: Color(0x2200E676),
    playerB: Color(0xFF00D4FF),
    playerBDark: Color(0xFF0090B8),
    playerBGlow: Color(0x6600D4FF),
    playerBFill: Color(0x2200D4FF),
    gold: Color(0xFF9EE37D),
    green: Color(0xFF00E676),
    red: Color(0xFFFF6E6E),
    onAccent: Color(0xFFFFFFFF),
    vsText: Color(0xFFB2E9F5),
    dotActive: Color(0xFFEFFFFF),
    dotGlow: Color(0x88EFFFFF),
    edgeInactive: Color(0x33D8FFFF),
    edgeHover: Color(0x66B8FBFF),
    boardSurface: Color(0xFF051114),
    boardGlow: Color(0xFF1A4A55),
    undoColor: Color(0xFF9EE37D),
    hintColor: Color(0xFFD8FF7A),
    newGameColor: Color(0xFF00E676),
  );

  static const DotClashVisuals aurora = DotClashVisuals(
    useGlow: true,
    scaffold: Color(0xFF0A0E19),
    backgroundGradientTop: Color(0xFF1A2345),
    surface: Color(0xFF101A2E),
    surfaceElevated: Color(0xFF16243E),
    cardBorder: Color(0xFF2D3F6B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF98A8D0),
    textDisabled: Color(0xFF495D8B),
    playerA: Color(0xFFB8FF30),
    playerADark: Color(0xFF86C800),
    playerAGlow: Color(0x66B8FF30),
    playerAFill: Color(0x22B8FF30),
    playerB: Color(0xFF9D4DFF),
    playerBDark: Color(0xFF6F2AC4),
    playerBGlow: Color(0x669D4DFF),
    playerBFill: Color(0x229D4DFF),
    gold: Color(0xFFFFD166),
    green: Color(0xFF7DDE6F),
    red: Color(0xFFFF6E6E),
    onAccent: Color(0xFFFFFFFF),
    vsText: Color(0xFFC8D7FF),
    dotActive: Color(0xFFFFFFFF),
    dotGlow: Color(0x88FFFFFF),
    edgeInactive: Color(0x33E0E7FF),
    edgeHover: Color(0x66C9D5FF),
    boardSurface: Color(0xFF0A0E19),
    boardGlow: Color(0xFF2D3F6B),
    undoColor: Color(0xFFFFD166),
    hintColor: Color(0xFFE9FF61),
    newGameColor: Color(0xFF7DDE6F),
  );

  static const DotClashVisuals royal = DotClashVisuals(
    useGlow: true,
    scaffold: Color(0xFF060A19),
    backgroundGradientTop: Color(0xFF13284C),
    surface: Color(0xFF0D1733),
    surfaceElevated: Color(0xFF142246),
    cardBorder: Color(0xFF274F88),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8EAAD2),
    textDisabled: Color(0xFF3E5C88),
    playerA: Color(0xFF4DDCFF),
    playerADark: Color(0xFF0D9FC4),
    playerAGlow: Color(0x664DDCFF),
    playerAFill: Color(0x224DDCFF),
    playerB: Color(0xFF6D5BFF),
    playerBDark: Color(0xFF4A3CC2),
    playerBGlow: Color(0x666D5BFF),
    playerBFill: Color(0x226D5BFF),
    gold: Color(0xFFFFD166),
    green: Color(0xFF63E3AF),
    red: Color(0xFFFF6E6E),
    onAccent: Color(0xFFFFFFFF),
    vsText: Color(0xFFC2D7FF),
    dotActive: Color(0xFFF4F8FF),
    dotGlow: Color(0x88F4F8FF),
    edgeInactive: Color(0x33D7E8FF),
    edgeHover: Color(0x6698BAFF),
    boardSurface: Color(0xFF060A19),
    boardGlow: Color(0xFF274F88),
    undoColor: Color(0xFFFFD166),
    hintColor: Color(0xFFFFEB61),
    newGameColor: Color(0xFF63E3AF),
  );

  static const DotClashVisuals sunset = DotClashVisuals(
    useGlow: true,
    scaffold: Color(0xFF1A100C),
    backgroundGradientTop: Color(0xFF3A1A12),
    surface: Color(0xFF22140F),
    surfaceElevated: Color(0xFF2C1A14),
    cardBorder: Color(0xFF6A3828),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD4A894),
    textDisabled: Color(0xFF6E4A3C),
    playerA: Color(0xFFFF7A45),
    playerADark: Color(0xFFCC4F1A),
    playerAGlow: Color(0x66FF7A45),
    playerAFill: Color(0x22FF7A45),
    playerB: Color(0xFFFF3D8A),
    playerBDark: Color(0xFFC2185B),
    playerBGlow: Color(0x66FF3D8A),
    playerBFill: Color(0x22FF3D8A),
    gold: Color(0xFFFFD166),
    green: Color(0xFF7DDE6F),
    red: Color(0xFFFF5C5C),
    onAccent: Color(0xFFFFFFFF),
    vsText: Color(0xFFFFD0C2),
    dotActive: Color(0xFFFFF5EE),
    dotGlow: Color(0x88FFF5EE),
    edgeInactive: Color(0x33FFE0D0),
    edgeHover: Color(0x66FFC4A8),
    boardSurface: Color(0xFF1A100C),
    boardGlow: Color(0xFF6A3828),
    undoColor: Color(0xFFFFD166),
    hintColor: Color(0xFFFFEB61),
    newGameColor: Color(0xFF7DDE6F),
  );

  static const DotClashVisuals frost = DotClashVisuals(
    useGlow: true,
    scaffold: Color(0xFF081218),
    backgroundGradientTop: Color(0xFF102838),
    surface: Color(0xFF0C1A22),
    surfaceElevated: Color(0xFF122430),
    cardBorder: Color(0xFF2A5A72),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9EC8DE),
    textDisabled: Color(0xFF3E5E72),
    playerA: Color(0xFFB8F0FF),
    playerADark: Color(0xFF6EB8D4),
    playerAGlow: Color(0x66B8F0FF),
    playerAFill: Color(0x22B8F0FF),
    playerB: Color(0xFF4D9FFF),
    playerBDark: Color(0xFF2A6FC4),
    playerBGlow: Color(0x664D9FFF),
    playerBFill: Color(0x224D9FFF),
    gold: Color(0xFFFFE082),
    green: Color(0xFF80E8C8),
    red: Color(0xFFFF7A8A),
    onAccent: Color(0xFF061018),
    vsText: Color(0xFFC8E8FF),
    dotActive: Color(0xFFF4FCFF),
    dotGlow: Color(0x88F4FCFF),
    edgeInactive: Color(0x33D8F4FF),
    edgeHover: Color(0x66B0E8FF),
    boardSurface: Color(0xFF081218),
    boardGlow: Color(0xFF2A5A72),
    undoColor: Color(0xFFFFE082),
    hintColor: Color(0xFFE0FFFF),
    newGameColor: Color(0xFF80E8C8),
  );

  static const DotClashVisuals voidTheme = DotClashVisuals(
    useGlow: true,
    scaffold: Color(0xFF050508),
    backgroundGradientTop: Color(0xFF120A24),
    surface: Color(0xFF0A0814),
    surfaceElevated: Color(0xFF12101F),
    cardBorder: Color(0xFF3D2A66),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA894D4),
    textDisabled: Color(0xFF4A3D66),
    playerA: Color(0xFFE040FF),
    playerADark: Color(0xFF9C1AB8),
    playerAGlow: Color(0x66E040FF),
    playerAFill: Color(0x22E040FF),
    playerB: Color(0xFF7C4DFF),
    playerBDark: Color(0xFF4F2AC4),
    playerBGlow: Color(0x667C4DFF),
    playerBFill: Color(0x227C4DFF),
    gold: Color(0xFFFFD166),
    green: Color(0xFF63E3AF),
    red: Color(0xFFFF6E9A),
    onAccent: Color(0xFFFFFFFF),
    vsText: Color(0xFFD8C8FF),
    dotActive: Color(0xFFF8F0FF),
    dotGlow: Color(0x88F8F0FF),
    edgeInactive: Color(0x33E8D8FF),
    edgeHover: Color(0x66C8A8FF),
    boardSurface: Color(0xFF050508),
    boardGlow: Color(0xFF3D2A66),
    undoColor: Color(0xFFFFD166),
    hintColor: Color(0xFFE9C0FF),
    newGameColor: Color(0xFF63E3AF),
  );

  static DotClashVisuals fromThemeId(String? themeId) {
    switch (themeId) {
      case 'theme_neon_ember':
        return ember;
      case 'theme_neon_mint':
        return mint;
      case 'theme_neon_aurora':
        return aurora;
      case 'theme_neon_royal':
        return royal;
      case 'theme_neon_sunset':
        return sunset;
      case 'theme_neon_frost':
        return frost;
      case 'theme_neon_void':
        return voidTheme;
      case 'theme_neon_default':
      default:
        return neon;
    }
  }

  @override
  DotClashVisuals copyWith({
    bool? useGlow,
    Color? scaffold,
    Color? backgroundGradientTop,
    Color? surface,
    Color? surfaceElevated,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? playerA,
    Color? playerADark,
    Color? playerAGlow,
    Color? playerAFill,
    Color? playerB,
    Color? playerBDark,
    Color? playerBGlow,
    Color? playerBFill,
    Color? gold,
    Color? green,
    Color? red,
    Color? onAccent,
    Color? vsText,
    Color? dotActive,
    Color? dotGlow,
    Color? edgeInactive,
    Color? edgeHover,
    Color? boardSurface,
    Color? boardGlow,
    Color? undoColor,
    Color? hintColor,
    Color? newGameColor,
  }) {
    return DotClashVisuals(
      useGlow: useGlow ?? this.useGlow,
      scaffold: scaffold ?? this.scaffold,
      backgroundGradientTop:
          backgroundGradientTop ?? this.backgroundGradientTop,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      playerA: playerA ?? this.playerA,
      playerADark: playerADark ?? this.playerADark,
      playerAGlow: playerAGlow ?? this.playerAGlow,
      playerAFill: playerAFill ?? this.playerAFill,
      playerB: playerB ?? this.playerB,
      playerBDark: playerBDark ?? this.playerBDark,
      playerBGlow: playerBGlow ?? this.playerBGlow,
      playerBFill: playerBFill ?? this.playerBFill,
      gold: gold ?? this.gold,
      green: green ?? this.green,
      red: red ?? this.red,
      onAccent: onAccent ?? this.onAccent,
      vsText: vsText ?? this.vsText,
      dotActive: dotActive ?? this.dotActive,
      dotGlow: dotGlow ?? this.dotGlow,
      edgeInactive: edgeInactive ?? this.edgeInactive,
      edgeHover: edgeHover ?? this.edgeHover,
      boardSurface: boardSurface ?? this.boardSurface,
      boardGlow: boardGlow ?? this.boardGlow,
      undoColor: undoColor ?? this.undoColor,
      hintColor: hintColor ?? this.hintColor,
      newGameColor: newGameColor ?? this.newGameColor,
    );
  }

  @override
  DotClashVisuals lerp(ThemeExtension<DotClashVisuals>? other, double t) {
    if (other is! DotClashVisuals) return this;
    return DotClashVisuals(
      useGlow: t < 0.5 ? useGlow : other.useGlow,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      backgroundGradientTop:
          Color.lerp(backgroundGradientTop, other.backgroundGradientTop, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      playerA: Color.lerp(playerA, other.playerA, t)!,
      playerADark: Color.lerp(playerADark, other.playerADark, t)!,
      playerAGlow: Color.lerp(playerAGlow, other.playerAGlow, t)!,
      playerAFill: Color.lerp(playerAFill, other.playerAFill, t)!,
      playerB: Color.lerp(playerB, other.playerB, t)!,
      playerBDark: Color.lerp(playerBDark, other.playerBDark, t)!,
      playerBGlow: Color.lerp(playerBGlow, other.playerBGlow, t)!,
      playerBFill: Color.lerp(playerBFill, other.playerBFill, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      green: Color.lerp(green, other.green, t)!,
      red: Color.lerp(red, other.red, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      vsText: Color.lerp(vsText, other.vsText, t)!,
      dotActive: Color.lerp(dotActive, other.dotActive, t)!,
      dotGlow: Color.lerp(dotGlow, other.dotGlow, t)!,
      edgeInactive: Color.lerp(edgeInactive, other.edgeInactive, t)!,
      edgeHover: Color.lerp(edgeHover, other.edgeHover, t)!,
      boardSurface: Color.lerp(boardSurface, other.boardSurface, t)!,
      boardGlow: Color.lerp(boardGlow, other.boardGlow, t)!,
      undoColor: Color.lerp(undoColor, other.undoColor, t)!,
      hintColor: Color.lerp(hintColor, other.hintColor, t)!,
      newGameColor: Color.lerp(newGameColor, other.newGameColor, t)!,
    );
  }
}

extension DotClashVisualsX on BuildContext {
  DotClashVisuals get dc {
    final ext = Theme.of(this).extension<DotClashVisuals>();
    return ext ?? DotClashVisuals.neon;
  }
}
