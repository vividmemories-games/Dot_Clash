import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/providers/onboarding_provider.dart';

/// Notifies [GoRouter] when onboarding completion changes so `redirect` runs
/// again without recreating [appRouterProvider] (stale `ref` in redirect).
final onboardingRouterRefreshProvider =
    Provider<OnboardingRouterRefresh>((ref) {
  final notifier = OnboardingRouterRefresh(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final class OnboardingRouterRefresh extends ChangeNotifier {
  OnboardingRouterRefresh(this._ref) {
    _sub = _ref.listen(onboardingSeenProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<bool>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
