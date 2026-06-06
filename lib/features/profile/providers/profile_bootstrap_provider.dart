import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_providers.dart';

/// Session bootstrap state — gates the tab shell until profile data is ready.
enum ProfileBootstrapState {
  /// Waiting for the first profile snapshot (Firestore or mock).
  loading,

  /// Profile loaded; safe to render home, theme, and campaign progress.
  ready,

  /// First profile fetch failed with no cached value.
  error,
}

/// True when signed-in UI can render real profile/theme/campaign data.
final profileBootstrapProvider = Provider<ProfileBootstrapState>((ref) {
  final profileAsync = ref.watch(profileProvider);

  if (profileAsync.hasValue) {
    return ProfileBootstrapState.ready;
  }

  if (profileAsync.hasError) {
    return ProfileBootstrapState.error;
  }

  // Mock repo yields synchronously; Firestore waits on _ensureExists + server.
  return ProfileBootstrapState.loading;
});

/// Equipped theme id — only applied after bootstrap completes to avoid flashes.
final equippedThemeIdProvider = Provider<String?>((ref) {
  final bootstrap = ref.watch(profileBootstrapProvider);
  if (bootstrap != ProfileBootstrapState.ready) return null;
  return ref.watch(profileProvider.select((value) => value.valueOrNull?.themeId));
});
