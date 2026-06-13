import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../home/domain/home_ui_models.dart';
import '../../home/providers/home_data_providers.dart';
import '../data/firestore_profile_repository.dart';
import '../data/mock_catalog_repository.dart';
import '../data/mock_profile_repository.dart';
import '../data/profile_repository.dart';
import '../domain/catalog.dart';
import '../domain/rank.dart';
import '../domain/user_profile.dart';

// ── Repositories (mock now; swap to Firebase later) ───────────────────────────

final catalogRepositoryProvider = Provider<MockCatalogRepository>((ref) {
  return const MockCatalogRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final uid = ref.watch(profileUidProvider);
  if (uid == null) return MockProfileRepository();
  final repo = FirestoreProfileRepository(uid: uid);
  ref.onDispose(repo.dispose);
  return repo;
});

// ── Profile stream ───────────────────────────────────────────────────────────

final profileProvider = StreamProvider<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});

// ── Derived view models ──────────────────────────────────────────────────────

final coinBalanceProvider = Provider<int>((ref) {
  return ref.watch(profileProvider).valueOrNull?.coins ?? 0;
});

final rankLabelProvider = Provider<String>((ref) {
  final p = ref.watch(profileProvider).valueOrNull;
  if (p == null) return '—';
  return '${RankSystem.label(p.rankTier)} • ${p.rating}';
});

final catalogProvider = Provider<CatalogSnapshot>((ref) {
  return ref.watch(catalogRepositoryProvider).getCatalog();
});

List<RecentMatch> _challengeMatchesFrom(Iterable<RecentMatch> matches) {
  return matches.where((m) => m.modeLabel == 'Challenge').toList();
}

/// Challenge rows from `profiles/{uid}/matches` (`modeLabel == Challenge`).
final challengeRecentMatchesProvider =
    Provider<AsyncValue<List<RecentMatch>>>((ref) {
  return ref.watch(recentMatchesProvider).whenData(_challengeMatchesFrom);
});

/// Extended challenge history for the full Challenge History screen.
final challengeMatchesExtendedProvider =
    StreamProvider<List<RecentMatch>>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchRecentMatches(limit: 50).map((records) {
    return records
        .map(
          (r) => RecentMatch(
            outcome: switch (r.outcome) {
              MatchResult.win => MatchOutcome.win,
              MatchResult.loss => MatchOutcome.loss,
              MatchResult.tie => MatchOutcome.tie,
            },
            modeLabel: r.modeLabel,
            opponentLabel: r.opponentLabel,
            playedAt: r.playedAt,
            opponentUid: r.opponentUid,
          ),
        )
        .where((m) => m.modeLabel == 'Challenge')
        .toList();
  });
});
