import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../services/backend/callable_backend.dart';

class AccountDeletionException implements Exception {
  AccountDeletionException(this.message, {this.requiresRecentLogin = false});

  final String message;
  final bool requiresRecentLogin;

  @override
  String toString() => message;
}

class AccountDeletionService {
  AccountDeletionService(this._backend, this._ref);

  final CallableBackend _backend;
  final Ref _ref;

  Future<void> deleteAccount({bool afterReauth = false}) async {
    try {
      await _backend.call('deleteUserData', const {});
    } on FirebaseFunctionsException catch (e) {
      if (!afterReauth && e.code == 'failed-precondition') {
        throw AccountDeletionException(
          e.message ?? 'Recent sign-in required.',
          requiresRecentLogin: true,
        );
      }
      throw AccountDeletionException(
        e.message ?? 'Could not delete account. Try again later.',
      );
    }
  }

  Future<void> reauthenticateForDeletion() async {
    try {
      await _ref.read(authActionsProvider).reauthenticateForSensitiveAction();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw AccountDeletionException(msg, requiresRecentLogin: true);
    }
  }

  Future<void> finalizeLocalCleanup() async {
    await _ref.read(settingsProvider.notifier).clearAllLocalData();
    await _ref.read(authActionsProvider).signOut();
  }
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(CallableBackend.instance, ref);
});
