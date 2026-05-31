import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../../../shared/widgets/neon_button.dart';

class RescueOfferSheet extends StatelessWidget {
  const RescueOfferSheet({
    super.key,
    required this.title,
    required this.message,
    required this.canWatchAd,
    required this.hasInventory,
    required this.inventoryLabel,
    required this.adLabel,
    required this.onWatchAd,
    required this.onUseInventory,
    required this.onDismiss,
    this.inventoryAccentColor,
  });

  final String title;
  final String message;
  final bool canWatchAd;
  final bool hasInventory;
  final String inventoryLabel;
  final String adLabel;
  final Future<void> Function() onWatchAd;
  final Future<void> Function() onUseInventory;
  final VoidCallback onDismiss;

  /// Primary CTA color for inventory use (defaults to theme red).
  final Color? inventoryAccentColor;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final inventoryColor = inventoryAccentColor ?? v.red;

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
          Text(title, style: t.playerName.copyWith(fontSize: 18)),
          AppSpacing.vGapSM,
          Text(message, style: t.bodySmall),
          AppSpacing.vGapMD,
          if (hasInventory)
            NeonButton(
              label: inventoryLabel,
              icon: Icons.replay_rounded,
              color: inventoryColor,
              onPressed: () async {
                await onUseInventory();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          if (canWatchAd) ...[
            AppSpacing.vGapSM,
            NeonButton(
              label: adLabel,
              icon: Icons.play_circle_outline_rounded,
              color: v.gold,
              onPressed: () async {
                await onWatchAd();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
          AppSpacing.vGapSM,
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDismiss();
            },
            child: Text(
              'NOT NOW',
              style: t.bodySmall.copyWith(color: v.textSecondary),
            ),
          ),
          AppSpacing.vGapMD,
        ],
      ),
    );
  }
}
