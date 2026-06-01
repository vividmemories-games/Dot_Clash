import 'package:dot_clash/core/theme/dot_clash_visuals.dart';
import 'package:dot_clash/shared/widgets/equipped_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DotClashVisuals.fromThemeId', () {
    test('resolves release 6 themes', () {
      expect(
        DotClashVisuals.fromThemeId('theme_neon_sunset'),
        DotClashVisuals.sunset,
      );
      expect(
        DotClashVisuals.fromThemeId('theme_neon_frost'),
        DotClashVisuals.frost,
      );
      expect(
        DotClashVisuals.fromThemeId('theme_neon_void'),
        DotClashVisuals.voidTheme,
      );
    });
  });

  group('EquippedAvatar.accentForAvatarId', () {
    test('resolves release 6 orbs', () {
      const v = DotClashVisuals.neon;
      expect(
        EquippedAvatar.accentForAvatarId('avatar_orb_lime', v),
        AvatarOrbColors.lime,
      );
      expect(
        EquippedAvatar.accentForAvatarId('avatar_orb_rose', v),
        AvatarOrbColors.rose,
      );
    });
  });
}
