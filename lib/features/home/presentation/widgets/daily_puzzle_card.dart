import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/home_data_providers.dart';

class DailyPuzzleCard extends ConsumerWidget {
  const DailyPuzzleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final profile = ref.watch(profileProvider).valueOrNull;
    final levelId = ref.watch(dailyPuzzleLevelIdProvider);
    final completed = profile?.isDailyPuzzleCompletedToday ?? false;
    final streak = profile?.dailyPuzzleStreak ?? 0;

    return GestureDetector(
      onTap: completed ? null : () => context.push(AppRoutes.dailyPuzzle),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: v.surface,
          borderRadius: AppSpacing.roundedLG,
          border: Border.all(color: v.playerB.withOpacity(0.55)),
        ),
        child: Row(
          children: [
            Icon(
              completed ? Icons.check_circle_rounded : Icons.extension_rounded,
              color: completed ? v.green : v.playerB,
              size: 28,
            ),
            AppSpacing.hGapMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY PUZZLE',
                    style: t.playerName.copyWith(fontSize: 15, color: v.playerB),
                  ),
                  AppSpacing.vGapXS,
                  Text(
                    completed
                        ? 'Completed today — come back tomorrow!'
                        : 'One shared board for everyone · $levelId',
                    style: t.bodySmall,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            if (streak > 0) ...[
              AppSpacing.hGapSM,
              Column(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: v.gold, size: 20),
                  Text(
                    '$streak',
                    style: t.bodySmall.copyWith(color: v.gold, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
            if (!completed)
              Icon(Icons.chevron_right_rounded, color: v.textSecondary),
          ],
        ),
      ),
    );
  }
}
