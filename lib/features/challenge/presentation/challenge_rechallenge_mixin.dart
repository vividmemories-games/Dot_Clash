import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/feedback/app_snackbar.dart';
import '../domain/challenge_exceptions.dart';
import '../providers/challenge_providers.dart';

/// Shared create-challenge flow for Profile + History screens.
mixin ChallengeRechallengeMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String? challengingUid;

  Future<void> rechallenge(String targetUid) async {
    if (challengingUid != null) return;
    setState(() => challengingUid = targetUid);
    try {
      final code = await ref
          .read(challengeRepositoryProvider)
          .createChallenge(targetUid: targetUid);
      if (!mounted) return;
      context.push(AppRoutes.challengeLobbyPath(code));
    } on ChallengeException catch (e) {
      if (mounted) AppSnackBar.show(context, e.message);
    } finally {
      if (mounted) setState(() => challengingUid = null);
    }
  }
}
