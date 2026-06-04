import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/app/package_info_provider.dart';
import '../../../core/env/app_env.dart';
import '../../../core/legal/legal_links.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/auth_router_refresh.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../features/account/data/account_deletion_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/ads/ad_consent_service.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/widgets/auth_provider_leading.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../../shared/widgets/neon_card.dart';
import '../../tutorial/data/ftue_preferences.dart';
import '../../tutorial/providers/coach_tour_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Future<void> _signOut(WidgetRef ref) async {
    await ref.read(authActionsProvider).signOut();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authRouterRefreshProvider).refresh();
    });
  }

  static Future<void> _replayTutorialTips(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await FtuePreferences.resetAll();
    ref.invalidate(ftuePreferencesProvider);
    ref.read(homeCoachTourProvider.notifier).reset();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tutorial tips reset. Visit Home to replay the tour.',
          ),
        ),
      );
    }
  }

  bool _isAccountConflictError(Object error) {
    if (error is AuthAccountConflictException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('already associated with a different user account') ||
        message.contains('credential-already-in-use') ||
        message.contains('already linked to another dot clash profile') ||
        message.contains('already in use');
  }

  Future<bool> _showConflictDialog(
    BuildContext context, {
    required String providerLabel,
  }) async {
    final shouldSwitch = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Account already has saved progress'),
          content: Text(
            'This $providerLabel account already has saved progress.\n\n'
            'Switch to that existing account, or keep your guest progress on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep guest progress'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Switch to $providerLabel'),
            ),
          ],
        );
      },
    );
    return shouldSwitch ?? false;
  }

  Future<void> _switchToExistingAccount(
    BuildContext context,
    WidgetRef ref, {
    required String providerLabel,
    Object? conflictError,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      User? signedInUser;
      final pendingCredential =
          (conflictError is AuthAccountConflictException)
              ? conflictError.pendingCredential
              : null;
      final canTryResolvedCredential = pendingCredential != null &&
          !(!kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              providerLabel == 'Google');

      if (canTryResolvedCredential) {
        // Reuse the exact conflicting credential first to avoid forcing
        // another provider prompt when Firebase already returned it.
        try {
          signedInUser = await ref
              .read(authActionsProvider)
              .signInWithResolvedCredential(pendingCredential);
        } catch (e) {
          debugPrint(
            '[Settings][switchToExistingAccount] resolved_credential_failed=$e',
          );
        }
      }

      if (signedInUser == null) {
        // Fallback path when pending credential is unavailable/unsupported.
        if (providerLabel == 'Google') {
          signedInUser = await ref.read(authActionsProvider).signInWithGoogle();
        } else {
          signedInUser = await ref.read(authActionsProvider).signInWithApple();
        }
      }
      if (signedInUser == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$providerLabel sign-in was canceled.')),
        );
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to your existing $providerLabel account.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final currentUser = ref.watch(currentUserProvider);
    final isAnonymousGuest = currentUser?.isAnonymous ?? false;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final providerIds =
        currentUser?.providerData.map((p) => p.providerId).toSet() ?? <String>{};
    final signedInWithGoogle = providerIds.contains('google.com');
    final signedInWithApple = providerIds.contains('apple.com');

    final body = SafeArea(
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          AppSpacing.vGapMD,

          // ── Gameplay ─────────────────────────────────────────────────────
          Text('GAMEPLAY', style: t.scoreLabel),
          AppSpacing.vGapSM,
          NeonCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  title: 'Show Timer',
                  subtitle: 'Display turn countdown',
                  value: settings.showTimer,
                  onChanged: notifier.setShowTimer,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Replay tutorial tips',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: v.textPrimary,
                        ),
                      ),
                      AppSpacing.vGapXS,
                      Text(
                        'Show the home tour and in-match coach marks again',
                        style: t.bodySmall,
                      ),
                      AppSpacing.vGapSM,
                      NeonButton(
                        label: 'REPLAY TIPS',
                        color: v.playerA,
                        width: double.infinity,
                        onPressed: () {
                          unawaited(_replayTutorialTips(context, ref));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.vGapLG,

          // ── Player names ────────────────────────────────────────────────
          Text('PLAYER NAMES',
              style: t.scoreLabel),
          AppSpacing.vGapSM,
          NeonCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlayerNameSection(
                  title: 'Local Game',
                  leftLabel: 'Player A',
                  leftValue: settings.localPlayerAName,
                  leftAccent: v.playerA,
                  onLeftChanged: notifier.setLocalPlayerAName,
                  onLeftCommit: notifier.commitLocalPlayerAName,
                  rightLabel: 'Player B',
                  rightValue: settings.localPlayerBName,
                  rightAccent: v.playerB,
                  onRightChanged: notifier.setLocalPlayerBName,
                  onRightCommit: notifier.commitLocalPlayerBName,
                ),
                AppSpacing.vGapSM,
                _PlayerNameSection(
                  title: 'Solo and Campaign',
                  leftLabel: 'You',
                  leftValue: settings.youName,
                  leftAccent: v.playerA,
                  onLeftChanged: notifier.setYouName,
                  onLeftCommit: notifier.commitYouName,
                  rightLabel: 'Rival',
                  rightValue: settings.aiName,
                  rightAccent: v.playerB,
                  onRightChanged: notifier.setAiName,
                  onRightCommit: notifier.commitAiName,
                ),
              ],
            ),
          ),

          AppSpacing.vGapLG,

          // ── Audio & haptics ──────────────────────────────────────────────
          Text('FEEDBACK', style: t.scoreLabel),
          AppSpacing.vGapSM,
          NeonCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  title: 'Haptics',
                  subtitle: 'Vibration on moves',
                  value: settings.hapticsEnabled,
                  onChanged: notifier.setHaptics,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  title: 'Sound Effects',
                  subtitle: 'Coming soon',
                  value: settings.soundEnabled,
                  onChanged: notifier.setSound,
                  enabled: false,
                ),
              ],
            ),
          ),

          AppSpacing.vGapLG,

          // ── Account ──────────────────────────────────────────────────────
          Text('ACCOUNT', style: t.scoreLabel),
          AppSpacing.vGapSM,
          if (isAnonymousGuest) ...[
            NeonCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save this guest profile to keep progress across devices.',
                    style: t.bodySmall,
                  ),
                  AppSpacing.vGapMD,
                  if (isIos) ...[
                    SizedBox(
                      width: double.infinity,
                      child: NeonButton(
                        label: 'Save progress with Apple',
                        leading: Icon(
                          Icons.apple_rounded,
                          size: 20,
                          color: v.playerB,
                        ),
                        color: v.playerB,
                        height: 58,
                        onPressed: () async {
                          var loaderOpen = true;
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          try {
                            final user = await ref
                                .read(authActionsProvider)
                                .linkAnonymousWithApple();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  user == null
                                      ? 'Apple sign-in was canceled.'
                                      : 'Progress saved to your Apple account.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            if (_isAccountConflictError(e)) {
                              Navigator.of(context, rootNavigator: true).pop();
                              loaderOpen = false;
                              final switchAccount = await _showConflictDialog(
                                context,
                                providerLabel: 'Apple',
                              );
                              if (!context.mounted) return;
                              if (switchAccount) {
                                await _switchToExistingAccount(
                                  context,
                                  ref,
                                  providerLabel: 'Apple',
                                  conflictError: e,
                                );
                              }
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          } finally {
                            if (context.mounted && loaderOpen) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }
                          }
                        },
                      ),
                    ),
                    AppSpacing.vGapMD,
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: 'Save progress with Google',
                      leading: const AuthProviderLeading.google(size: 18),
                      color: v.playerA,
                      height: 58,
                      onPressed: () async {
                        var loaderOpen = true;
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                        try {
                          final user = await ref
                              .read(authActionsProvider)
                              .linkAnonymousWithGoogle();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                user == null
                                    ? 'Google sign-in was canceled.'
                                    : 'Progress saved to your Google account.',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          if (_isAccountConflictError(e)) {
                            Navigator.of(context, rootNavigator: true).pop();
                            loaderOpen = false;
                            final switchAccount = await _showConflictDialog(
                              context,
                              providerLabel: 'Google',
                            );
                            if (!context.mounted) return;
                            if (switchAccount) {
                              await _switchToExistingAccount(
                                context,
                                ref,
                                providerLabel: 'Google',
                                conflictError: e,
                              );
                            }
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        } finally {
                          if (context.mounted && loaderOpen) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vGapSM,
          ],
          NeonCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: NeonButton(
                label: signedInWithGoogle
                    ? 'Sign out with Google'
                    : (signedInWithApple ? 'Sign out with Apple' : 'Sign out'),
                leading: signedInWithGoogle
                    ? const AuthProviderLeading.google(size: 18)
                    : (signedInWithApple
                        ? Icon(Icons.apple_rounded, size: 20, color: v.playerB)
                        : Icon(Icons.logout_rounded, size: 18, color: v.red)),
                color: signedInWithGoogle
                    ? v.playerA
                    : (signedInWithApple ? v.playerB : v.red),
                height: 58,
                onPressed: () => _signOut(ref),
              ),
            ),
          ),

          AppSpacing.vGapLG,

          const _HelpLegalSection(),

          AppSpacing.vGapLG,

          Center(
            child: Text(
              'Dot Clash  v1.0.0',
              style: t.bodySmall,
            ),
          ),
          AppSpacing.vGapLG,
        ],
      ),
    );

    return Scaffold(
      backgroundColor: v.scaffold,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('SETTINGS'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: Icon(Icons.logout, color: v.red),
            onPressed: () => _signOut(ref),
          ),
        ],
      ),
      body: body,
    );
  }
}

// ── Help & legal ──────────────────────────────────────────────────────────────

class _HelpLegalSection extends ConsumerStatefulWidget {
  const _HelpLegalSection();

  @override
  ConsumerState<_HelpLegalSection> createState() => _HelpLegalSectionState();
}

class _HelpLegalSectionState extends ConsumerState<_HelpLegalSection> {
  late Future<bool> _privacyOptionsRequired;

  @override
  void initState() {
    super.initState();
    _privacyOptionsRequired =
        AdConsentService.instance.isPrivacyOptionsRequired();
  }

  Future<void> _openPrivacyOptions() async {
    await AdConsentService.instance.showPrivacyOptions();
    if (!mounted) return;
    setState(() {
      _privacyOptionsRequired =
          AdConsentService.instance.isPrivacyOptionsRequired();
    });
  }

  Future<void> _showAboutSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _AboutSheet(),
    );
  }

  Future<void> _showTermsAndPrivacySheet() async {
    final firebaseOn = ref.read(firebaseConfiguredProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TermsAndPrivacySheet(
        firebaseOn: firebaseOn,
        privacyOptionsRequired: _privacyOptionsRequired,
        onOpenPrivacyOptions: () async {
          Navigator.of(sheetContext).pop();
          await _openPrivacyOptions();
        },
        onDeleteAccount: () {
          Navigator.of(sheetContext).pop();
          _confirmDeleteAccount(context);
        },
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final v = context.dc;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, cloud save, match history, '
          'and progress. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: v.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    final controller = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type DELETE to confirm.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: v.red),
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim() == 'DELETE'),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (typed != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final deletion = ref.read(accountDeletionServiceProvider);
    try {
      await deletion.deleteAccount();
    } on AccountDeletionException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (e.requiresRecentLogin) {
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign in again'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sign in & delete'),
              ),
            ],
          ),
        );
        if (retry != true || !context.mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        try {
          await deletion.reauthenticateForDeletion();
          await deletion.deleteAccount(afterReauth: true);
        } catch (err) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$err')),
            );
          }
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      return;
    }

    await deletion.finalizeLocalCleanup();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    context.go(AppRoutes.auth);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your account was deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final firebaseOn = ref.watch(firebaseConfiguredProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HELP & LEGAL', style: t.scoreLabel),
        AppSpacing.vGapSM,
        NeonCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.support_agent_outlined, color: v.playerB),
                title: const Text('Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: firebaseOn
                    ? () => context.push(AppRoutes.contact)
                    : null,
                enabled: firebaseOn,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.info_outline, color: v.gold),
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAboutSheet,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.shield_outlined, color: v.playerA),
                title: const Text('Terms and Privacy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showTermsAndPrivacySheet,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutSheet extends ConsumerWidget {
  const _AboutSheet();

  static String _environmentLabel() {
    if (AppEnv.isDev) return 'Development';
    if (AppEnv.betaAds) return 'Production (closed testing — test ads)';
    return 'Production';
  }

  static String _copyLine(PackageInfo info) {
    final env = AppEnv.flavor;
    final beta = AppEnv.betaAds ? ' beta_ads' : '';
    return '${info.appName} ${info.version} (${info.buildNumber}) $env$beta';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final infoAsync = ref.watch(packageInfoProvider);

    return Container(
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: v.cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
      child: infoAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Could not load app info.',
            style: t.body.copyWith(color: v.textSecondary),
          ),
        ),
        data: (info) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: v.cardBorder,
                    borderRadius: AppSpacing.roundedFull,
                  ),
                ),
              ),
              Text('ABOUT', style: t.scoreLabel),
              AppSpacing.vGapSM,
              NeonCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    _AboutRow(
                      label: 'App',
                      value: info.appName,
                    ),
                    _AboutRow(
                      label: 'Version',
                      value: info.version,
                    ),
                    _AboutRow(
                      label: 'Build',
                      value: info.buildNumber,
                    ),
                    _AboutRow(
                      label: 'Environment',
                      value: _environmentLabel(),
                    ),
                    _AboutRow(
                      label: 'Package',
                      value: info.packageName,
                      mono: true,
                    ),
                  ],
                ),
              ),
              AppSpacing.vGapMD,
              NeonButton(
                label: 'Copy for support',
                icon: Icons.copy_outlined,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _copyLine(info)),
                  );
                  if (context.mounted) {
                    AppSnackBar.show(context, 'Copied version info');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: t.bodySmall.copyWith(color: v.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: (mono ? t.bodySmall : t.body).copyWith(
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsAndPrivacySheet extends StatelessWidget {
  const _TermsAndPrivacySheet({
    required this.firebaseOn,
    required this.privacyOptionsRequired,
    required this.onOpenPrivacyOptions,
    required this.onDeleteAccount,
  });

  final bool firebaseOn;
  final Future<bool> privacyOptionsRequired;
  final Future<void> Function() onOpenPrivacyOptions;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: v.cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: v.cardBorder,
                borderRadius: AppSpacing.roundedFull,
              ),
            ),
          ),
          Text(
            'TERMS AND PRIVACY',
            style: t.scoreLabel,
          ),
          AppSpacing.vGapSM,
          NeonCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.policy_outlined, color: v.playerA),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    Navigator.of(context).pop();
                    LegalLinks.openPrivacyPolicy();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.description_outlined, color: v.playerA),
                  title: const Text('Terms and Conditions'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    Navigator.of(context).pop();
                    LegalLinks.openTerms();
                  },
                ),
                const Divider(height: 1),
                FutureBuilder<bool>(
                  future: privacyOptionsRequired,
                  builder: (context, snap) {
                    final required = snap.data ?? false;
                    return ListTile(
                      leading: Icon(Icons.ads_click_outlined, color: v.gold),
                      title: Text(
                        required ? 'Manage Ad Consent' : 'Ad Consent',
                      ),
                      subtitle: required
                          ? null
                          : Text(
                              'Choices also available in device settings',
                              style: t.bodySmall,
                            ),
                      trailing: required
                          ? const Icon(Icons.chevron_right)
                          : Icon(
                              Icons.open_in_new,
                              size: 18,
                              color: v.textSecondary,
                            ),
                      onTap: () {
                        if (required) {
                          onOpenPrivacyOptions();
                        } else {
                          Navigator.of(context).pop();
                          LegalLinks.openPrivacyChoices();
                        }
                      },
                    );
                  },
                ),
                if (firebaseOn) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        Icon(Icons.delete_forever_outlined, color: v.red),
                    title: Text(
                      'Delete My Account',
                      style: TextStyle(
                        color: v.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently remove account and cloud data',
                      style: t.bodySmall,
                    ),
                    onTap: onDeleteAccount,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Setting tile widgets ───────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: enabled ? v.textPrimary : v.textDisabled,
        ),
      ),
      subtitle: Text(subtitle, style: t.bodySmall),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: v.playerA,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

class _PlayerNameSection extends StatelessWidget {
  const _PlayerNameSection({
    required this.title,
    required this.leftLabel,
    required this.leftValue,
    required this.onLeftChanged,
    required this.onLeftCommit,
    required this.rightLabel,
    required this.rightValue,
    required this.onRightChanged,
    required this.onRightCommit,
    this.leftAccent,
    this.rightAccent,
  });

  final String title;
  final String leftLabel;
  final String leftValue;
  final ValueChanged<String> onLeftChanged;
  final ValueChanged<String> onLeftCommit;
  final String rightLabel;
  final String rightValue;
  final ValueChanged<String> onRightChanged;
  final ValueChanged<String> onRightCommit;
  final Color? leftAccent;
  final Color? rightAccent;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: v.surfaceElevated,
        borderRadius: AppSpacing.roundedMD,
        border: Border.all(
          color: v.cardBorder.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: t.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: v.textSecondary,
              ),
            ),
            AppSpacing.vGapSM,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _NameField(
                    label: leftLabel,
                    value: leftValue,
                    accentColor: leftAccent,
                    onChanged: onLeftChanged,
                    onCommit: onLeftCommit,
                    compact: true,
                  ),
                ),
                AppSpacing.hGapSM,
                Expanded(
                  child: _NameField(
                    label: rightLabel,
                    value: rightValue,
                    accentColor: rightAccent,
                    onChanged: onRightChanged,
                    onCommit: onRightCommit,
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onCommit,
    this.accentColor,
    this.compact = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCommit;
  final Color? accentColor;
  final bool compact;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(_NameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      widget.onCommit(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    return Padding(
      padding: widget.compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.accentColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                AppSpacing.hGapXS,
              ],
              Expanded(
                child: Text(
                  widget.label,
                  style: t.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            onEditingComplete: () => widget.onCommit(_controller.text),
            textInputAction: TextInputAction.next,
            style: TextStyle(
              color: v.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            decoration: InputDecoration(
              hintText: 'Name',
              isDense: widget.compact,
            ),
          ),
        ],
      ),
    );
  }
}
