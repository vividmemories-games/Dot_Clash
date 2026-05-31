import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

/// Notifies [GoRouter] when auth state changes so `redirect` runs again.
final authRouterRefreshProvider = Provider<AuthRouterRefresh>((ref) {
  final notifier = AuthRouterRefresh(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(this._ref) {
    _sub = _ref.listen<AsyncValue<User?>>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<User?>> _sub;

  /// Re-runs GoRouter `redirect` (e.g. after sign-in when providers have settled).
  void refresh() => notifyListeners();

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
