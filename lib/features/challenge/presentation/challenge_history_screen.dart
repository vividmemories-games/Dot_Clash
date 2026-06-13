import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../profile/providers/profile_providers.dart';
import '../../home/domain/home_ui_models.dart';
import '../domain/head_to_head_stats.dart';
import 'challenge_rechallenge_mixin.dart';
import 'widgets/challenge_history_widgets.dart';

class ChallengeHistoryScreen extends ConsumerStatefulWidget {
  const ChallengeHistoryScreen({super.key});

  @override
  ConsumerState<ChallengeHistoryScreen> createState() =>
      _ChallengeHistoryScreenState();
}

class _ChallengeHistoryScreenState extends ConsumerState<ChallengeHistoryScreen>
    with ChallengeRechallengeMixin {
  static const _tabLabels = ['RIVALS', 'HISTORY'];

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final matchesAsync = ref.watch(challengeMatchesExtendedProvider);

    return DefaultTabController(
      length: _tabLabels.length,
      child: Scaffold(
        backgroundColor: v.scaffold,
        appBar: AppBar(
          backgroundColor: v.scaffold,
          foregroundColor: v.textPrimary,
          elevation: 0,
          title: Text(
            'CHALLENGE HISTORY',
            style: context.txt.playerName.copyWith(fontSize: 14),
          ),
        ),
        body: matchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => SafeArea(
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: ChallengeHistoryEmptyState(
                message: 'Could not load challenge history.',
              ),
            ),
          ),
          data: (matches) {
            final rivals = HeadToHeadStats.allRivals(matches);
            final history = HeadToHeadStats.chronologicalHistory(matches);

            return SafeArea(
              child: Column(
                children: [
                  const ChallengeHistoryTabBar(labels: _tabLabels),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _RivalsTab(
                          rivals: rivals,
                          challengingUid: challengingUid,
                          onRechallenge: rechallenge,
                        ),
                        _HistoryTab(history: history),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RivalsTab extends StatelessWidget {
  const _RivalsTab({
    required this.rivals,
    required this.challengingUid,
    required this.onRechallenge,
  });

  final List<ChallengeRival> rivals;
  final String? challengingUid;
  final void Function(String targetUid) onRechallenge;

  @override
  Widget build(BuildContext context) {
    if (rivals.isEmpty) {
      return ListView(
        padding: AppSpacing.pagePadding,
        children: const [
          ChallengeHistoryEmptyState(
            message:
                'No rivalries yet. Challenge a friend from Home to start a series.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: AppSpacing.pagePadding,
      itemCount: rivals.length,
      separatorBuilder: (_, __) => AppSpacing.vGapSM,
      itemBuilder: (context, index) {
        final rival = rivals[index];
        return RivalListTile(
          rival: rival,
          busy: challengingUid == rival.uid,
          enabled: challengingUid == null,
          onRechallenge: () => onRechallenge(rival.uid),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history});

  final List<RecentMatch> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return ListView(
        padding: AppSpacing.pagePadding,
        children: const [
          ChallengeHistoryEmptyState(
            message: 'No challenge matches yet.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: AppSpacing.pagePadding,
      itemCount: history.length,
      separatorBuilder: (_, __) => AppSpacing.vGapSM,
      itemBuilder: (context, index) {
        return MatchHistoryTile(match: history[index]);
      },
    );
  }
}
