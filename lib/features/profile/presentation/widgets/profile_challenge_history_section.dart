import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/challenge/presentation/challenge_rechallenge_mixin.dart';
import '../../../../features/challenge/presentation/widgets/challenge_history_widgets.dart';
import '../../../../features/challenge/providers/challenge_providers.dart';
import '../../../../shared/layout/app_spacing.dart';

/// Compact rival preview on Profile — full history lives on [ChallengeHistoryScreen].
class ProfileChallengeHistorySection extends ConsumerStatefulWidget {
  const ProfileChallengeHistorySection({super.key});

  @override
  ConsumerState<ProfileChallengeHistorySection> createState() =>
      _ProfileChallengeHistorySectionState();
}

class _ProfileChallengeHistorySectionState
    extends ConsumerState<ProfileChallengeHistorySection>
    with ChallengeRechallengeMixin {
  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final rivalsAsync = ref.watch(challengeRivalsProvider);

    return rivalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (rivals) {
        final topRival = rivals.isEmpty ? null : rivals.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RIVALRIES', style: t.scoreLabel),
            AppSpacing.vGapSM,
            if (topRival == null)
              const _EmptyRivalriesCard()
            else
              RivalSummaryCard(
                rival: topRival,
                busy: challengingUid == topRival.uid,
                enabled: challengingUid == null,
                onRechallenge: () => rechallenge(topRival.uid),
              ),
            if (topRival != null) ...[
              AppSpacing.vGapSM,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: v.textPrimary,
                    side: BorderSide(color: v.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.roundedMD,
                    ),
                  ),
                  onPressed: () => context.push(AppRoutes.challengeHistory),
                  child: Text(
                    'VIEW ALL RIVALRIES',
                    style: t.scoreLabel.copyWith(
                      fontSize: 10,
                      color: v.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyRivalriesCard extends StatelessWidget {
  const _EmptyRivalriesCard();

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: AppSpacing.roundedLG,
        border: Border.all(color: v.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No rivalries yet',
            style: t.playerName.copyWith(fontSize: 15),
          ),
          AppSpacing.vGapXS,
          Text(
            'Remember this game from class? Challenge a friend from Home.',
            style: t.bodySmall.copyWith(color: v.textSecondary),
          ),
        ],
      ),
    );
  }
}
