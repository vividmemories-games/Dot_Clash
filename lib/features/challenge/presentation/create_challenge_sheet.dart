import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';
import '../domain/challenge_board_preset.dart';
import '../domain/challenge_exceptions.dart';
import '../providers/challenge_providers.dart';
import 'widgets/challenge_board_preview_card.dart';

class CreateChallengeSheet extends ConsumerStatefulWidget {
  const CreateChallengeSheet({super.key});

  @override
  ConsumerState<CreateChallengeSheet> createState() =>
      _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends ConsumerState<CreateChallengeSheet> {
  String _selectedPresetId = ChallengeBoardPreset.defaultPresetId;
  bool _creating = false;

  Future<void> _startChallenge() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final result =
          await ref.read(challengeRepositoryProvider).createChallenge(
                boardPresetId: _selectedPresetId,
              );
      if (!mounted) return;
      Navigator.pop(context);
      context.push(AppRoutes.challengeLobbyPath(result.code));
    } on ChallengeException catch (e) {
      if (mounted) AppSnackBar.show(context, e.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text('CHOOSE YOUR BOARD', style: t.scoreLabel),
          AppSpacing.vGapXS,
          Text(
            'Your friend will see this before they join.',
            style: t.bodySmall.copyWith(color: v.textSecondary),
          ),
          AppSpacing.vGapSM,
          for (final preset in ChallengeBoardPreset.all) ...[
            ChallengeBoardPreviewCard(
              preset: preset,
              selected: _selectedPresetId == preset.id,
              onTap: _creating
                  ? null
                  : () => setState(() => _selectedPresetId = preset.id),
            ),
            AppSpacing.vGapSM,
          ],
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: _creating ? 'CREATING…' : 'START CHALLENGE',
              icon: Icons.add_rounded,
              color: v.playerA,
              enabled: !_creating,
              onPressed: _creating ? null : _startChallenge,
            ),
          ),
          AppSpacing.vGapMD,
        ],
      ),
    );
  }
}

Future<void> showCreateChallengeSheet(BuildContext context) {
  final v = context.dc;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: v.surface,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: v.cardBorder),
    ),
    builder: (sheetContext) {
      final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: const CreateChallengeSheet(),
      );
    },
  );
}
