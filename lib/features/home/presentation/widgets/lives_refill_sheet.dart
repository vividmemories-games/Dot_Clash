import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../features/profile/domain/progression.dart';
import '../../../../features/profile/providers/lives_provider.dart';
import '../../../../features/profile/providers/profile_providers.dart';
import '../../../../shared/feedback/app_snackbar.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/neon_button.dart';

class LivesRefillSheet extends ConsumerWidget {
  const LivesRefillSheet({
    super.key,
    required this.onBuyLife,
    this.onWatchAd,
  });

  final Future<bool> Function() onBuyLife;
  final Future<bool> Function()? onWatchAd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final snapshot = ref.watch(livesSnapshotProvider);
    final coins = ref.watch(profileProvider).valueOrNull?.coins ?? 0;
    final canBuy =
        !snapshot.isFull && coins >= Progression.lifeRefillPriceCoins;

    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.vGapSM,
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: v.cardBorder,
                borderRadius: AppSpacing.roundedFull,
              ),
            ),
          ),
          AppSpacing.vGapMD,
          Text('LIVES', style: t.scoreLabel),
          AppSpacing.vGapSM,
          Text(
            snapshot.isFull
                ? 'You have full lives.'
                : 'Lives: ${snapshot.effectiveLives}/${Progression.maxLives}',
            style: t.playerName.copyWith(fontSize: 16),
          ),
          if (!snapshot.isFull) ...[
            AppSpacing.vGapXS,
            Text(
              snapshot.timeUntilNextLife == null
                  ? 'Next life: soon'
                  : 'Next life in ${_formatDuration(snapshot.timeUntilNextLife!)}',
              style: t.bodySmall,
            ),
          ],
          AppSpacing.vGapMD,
          NeonButton(
            label: snapshot.isFull
                ? 'Lives Full'
                : 'Buy 1 life (${Progression.lifeRefillPriceCoins} coins)',
            icon: Icons.favorite_rounded,
            color: v.red,
            onPressed: canBuy
                ? () async {
                    final ok = await onBuyLife();
                    if (!context.mounted) return;
                    AppSnackBar.show(
                      context,
                      ok ? 'Life purchased!' : 'Purchase failed.',
                    );
                  }
                : null,
          ),
          if (!snapshot.isFull && onWatchAd != null) ...[
            AppSpacing.vGapSM,
            NeonButton(
              label: 'Watch ad · +1 life',
              icon: Icons.play_circle_outline_rounded,
              color: v.gold,
              onPressed: () async {
                final ok = await onWatchAd!();
                if (!context.mounted) return;
                AppSnackBar.show(
                  context,
                  ok
                      ? 'Life restored!'
                      : 'Ad unavailable or daily cap reached.',
                );
              },
            ),
          ],
          if (!snapshot.isFull && !canBuy) ...[
            AppSpacing.vGapXS,
            Text('Not enough coins.', style: t.bodySmall),
          ],
          AppSpacing.vGapMD,
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
