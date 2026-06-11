import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';

/// Share challenge code + link copy (HTTPS primary in Phase 4).
class ChallengeShareSheet extends StatelessWidget {
  const ChallengeShareSheet({
    super.key,
    required this.code,
    required this.hostDisplayName,
  });

  final String code;
  final String hostDisplayName;

  static const httpsJoinBase =
      'https://vividmemories-games.github.io/join';

  String get httpsLink => '$httpsJoinBase/$code';
  String get customSchemeLink => 'dotclash://join/$code';

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSpacing.vGapSM,
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: v.cardBorder,
              borderRadius: AppSpacing.roundedFull,
            ),
          ),
          AppSpacing.vGapMD,
          Text('SHARE CHALLENGE', style: t.scoreLabel),
          AppSpacing.vGapSM,
          Text(
            'Send this code to a friend',
            style: t.bodySmall.copyWith(color: v.textSecondary),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapMD,
          SelectableText(
            code,
            style: t.heroTitle.copyWith(
              fontSize: 36,
              letterSpacing: 6,
              color: v.playerA,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapMD,
          _CopyRow(
            label: 'Link',
            value: httpsLink,
            v: v,
            t: t,
          ),
          AppSpacing.vGapSM,
          _CopyRow(
            label: 'App link',
            value: customSchemeLink,
            v: v,
            t: t,
          ),
          AppSpacing.vGapMD,
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: 'COPY CODE',
              icon: Icons.copy_rounded,
              color: v.playerA,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Code $code copied')),
                  );
                }
              },
            ),
          ),
          AppSpacing.vGapSM,
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: 'COPY LINK',
              icon: Icons.link_rounded,
              color: v.playerB,
              onPressed: () async {
                final shareText =
                    'Challenge me on Dot Clash! $httpsLink (code: $code)';
                await Clipboard.setData(ClipboardData(text: shareText));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share text copied')),
                  );
                }
              },
            ),
          ),
          AppSpacing.vGapMD,
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.v,
    required this.t,
  });

  final String label;
  final String value;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: v.surfaceElevated,
        borderRadius: AppSpacing.roundedMD,
        border: Border.all(color: v.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: t.bodySmall),
          AppSpacing.vGapXS,
          Text(
            value,
            style: t.body.copyWith(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

Future<void> showChallengeShareSheet({
  required BuildContext context,
  required String code,
  required String hostDisplayName,
}) {
  final v = context.dc;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: v.surface,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: v.cardBorder),
    ),
    builder: (_) => ChallengeShareSheet(
      code: code,
      hostDisplayName: hostDisplayName,
    ),
  );
}
