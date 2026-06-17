import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';

class JoinChallengeSheet extends ConsumerStatefulWidget {
  const JoinChallengeSheet({super.key});

  @override
  ConsumerState<JoinChallengeSheet> createState() => _JoinChallengeSheetState();
}

class _JoinChallengeSheetState extends ConsumerState<JoinChallengeSheet> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.length != 6) {
      AppSnackBar.show(context, 'Enter a 6-character code.');
      return;
    }

    setState(() => _loading = true);
    try {
      final code = raw.trim().toUpperCase();
      if (!mounted) return;
      Navigator.pop(context);
      context.push(AppRoutes.challengeLobbyPath(code));
    } finally {
      if (mounted) setState(() => _loading = false);
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
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: v.cardBorder,
              borderRadius: AppSpacing.roundedFull,
            ),
          ),
          AppSpacing.vGapMD,
          Text('JOIN CHALLENGE', style: t.scoreLabel),
          AppSpacing.vGapSM,
          Text(
            'Enter the 6-character code — you\'ll preview the board before joining',
            style: t.bodySmall.copyWith(color: v.textSecondary),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapMD,
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_loading,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: t.heroTitle.copyWith(
              fontSize: 28,
              letterSpacing: 4,
              color: v.playerB,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              filled: true,
              fillColor: v.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: AppSpacing.roundedMD,
                borderSide: BorderSide(color: v.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppSpacing.roundedMD,
                borderSide: BorderSide(color: v.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppSpacing.roundedMD,
                borderSide: BorderSide(color: v.playerB),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          AppSpacing.vGapMD,
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: _loading ? 'OPENING…' : 'CONTINUE',
              icon: Icons.login_rounded,
              color: v.playerB,
              enabled: !_loading,
              onPressed: _loading ? null : _submit,
            ),
          ),
          AppSpacing.vGapMD,
        ],
      ),
    );
  }
}

Future<void> showJoinChallengeSheet(BuildContext context) {
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
        child: const JoinChallengeSheet(),
      );
    },
  );
}
