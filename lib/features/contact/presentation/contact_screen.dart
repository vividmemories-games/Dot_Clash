import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env/app_env.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../../shared/widgets/neon_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../contact_mailto.dart';

class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  Future<void> _emailSupport(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    final settings = ref.read(settingsProvider);
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName
        : settings.youName;

    final ok = await openSupportEmail(user: user, displayName: displayName);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open your mail app. Email us at ${AppEnv.contactEmail}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;

    return Scaffold(
      backgroundColor: v.scaffold,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('CONTACT US'),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            Text(
              'Questions about gameplay, privacy, ads, or your account?',
              style: t.body,
            ),
            AppSpacing.vGapMD,
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email support',
                    style: t.playerName.copyWith(color: v.playerB),
                  ),
                  AppSpacing.vGapSM,
                  Text(
                    'Tap below to open your mail app with a pre-filled message. '
                    'Add a short description of your issue and send — we usually '
                    'reply within a few business days.',
                    style: t.bodySmall,
                  ),
                  AppSpacing.vGapMD,
                  Text(
                    'Helpful to include:',
                    style: t.bodySmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                  AppSpacing.vGapXS,
                  Text(
                    '• What you were doing when the issue happened\n'
                    '• Your display name in the app\n'
                    '• How you sign in (Google, Apple, or guest)',
                    style: t.bodySmall,
                  ),
                  AppSpacing.vGapLG,
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: 'Email support',
                      icon: Icons.mail_outline_rounded,
                      color: v.playerB,
                      onPressed: () => _emailSupport(context, ref),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vGapMD,
            Text(
              'Support: ${AppEnv.contactEmail}',
              style: t.bodySmall.copyWith(color: v.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
