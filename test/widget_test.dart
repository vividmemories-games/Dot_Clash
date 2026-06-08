import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dot_clash/core/theme/app_theme.dart';
import 'package:dot_clash/features/home/presentation/widgets/home_action_row.dart';
import 'package:dot_clash/features/profile/domain/lives_logic.dart';
import 'package:dot_clash/features/profile/domain/progression.dart';
import 'package:dot_clash/features/profile/providers/lives_provider.dart';

void main() {
  testWidgets('HomeActionRow shows quick match and local actions',
      (tester) async {
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
            body: HomeActionRow(
              onAiTap: () {},
              onLocalTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('QUICK MATCH'), findsOneWidget);
    expect(find.text('LOCAL'), findsOneWidget);
  });
}
