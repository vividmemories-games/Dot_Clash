import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dot_clash/core/theme/app_theme.dart';
import 'package:dot_clash/features/home/presentation/widgets/play_modes_grid.dart';
import 'package:dot_clash/features/profile/domain/lives_logic.dart';
import 'package:dot_clash/features/profile/domain/progression.dart';
import 'package:dot_clash/features/profile/providers/lives_provider.dart';

void main() {
  testWidgets('PlayModesGrid shows all four play mode tiles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          livesSnapshotProvider.overrideWithValue(
            const LivesSnapshot(
              effectiveLives: Progression.maxLives,
              nextLifeAt: null,
              timeUntilNextLife: null,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.neon(),
          home: Scaffold(
            body: PlayModesGrid(
              onAiTap: () {},
              onLocalTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('QUICK MATCH'), findsOneWidget);
    expect(find.text('CHALLENGE'), findsOneWidget);
    expect(find.text('DAILY PUZZLE'), findsOneWidget);
    expect(find.text('LOCAL'), findsOneWidget);
    expect(find.text('PLAY NOW'), findsNothing);
  });
}
