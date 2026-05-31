import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kOnboardingSeenKey = 'onboarding_seen_v1';

/// Returns true if the user has already seen the onboarding splash.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kOnboardingSeenKey) ?? false;
}

/// Marks the onboarding as seen so it's never shown again.
Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kOnboardingSeenKey, true);
}

final onboardingSeenProvider =
    FutureProvider<bool>((ref) => hasSeenOnboarding());

/// Persists onboarding completion and reloads [onboardingSeenProvider].
/// [OnboardingRouterRefresh] notifies GoRouter to re-run `redirect`.
Future<void> completeOnboarding(WidgetRef ref) async {
  if (await hasSeenOnboarding()) return;
  await markOnboardingSeen();
  ref.invalidate(onboardingSeenProvider);
  await ref.read(onboardingSeenProvider.future);
}
