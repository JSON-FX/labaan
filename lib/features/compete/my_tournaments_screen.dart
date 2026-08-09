import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/data/repos.dart';
import '../../core/domain/tournament_tier.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/game_art.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/lb_chip.dart';
import '../../core/widgets/rank_hex.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/team_avatar.dart';

/// Compete · 1A · My Tournaments.
///
/// Consumes [myTournamentsProvider]. Renders skeleton while loading, empty
/// state per tab when nothing to show, error with retry on failure.
class MyTournamentsScreen extends ConsumerStatefulWidget {
  const MyTournamentsScreen({super.key});

  @override
  ConsumerState<MyTournamentsScreen> createState() =>
      _MyTournamentsScreenState();
}

class _MyTournamentsScreenState extends ConsumerState<MyTournamentsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    final async = ref.watch(myTournamentsProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tournaments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: _SegmentedTabs(
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              counts: async.when(
                data: (d) =>
                    (d.live.length, d.upcoming.length, d.completed.length),
                loading: () => (0, 0, 0),
                error: (_, _) => (0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: LbColors.lime,
              backgroundColor: LbColors.surface,
              onRefresh: () async {
                ref.invalidate(myTournamentsProvider(user.id));
                await ref.read(myTournamentsProvider(user.id).future);
              },
              child: async.when(
                loading: () => const _Skeleton(),
                error: (err, _) => _ErrorState(
                  message: 'Could not load your tournaments',
                  onRetry: () => ref.invalidate(myTournamentsProvider(user.id)),
                ),
                data: (d) => _TabBody(tab: _tab, data: d),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab, required this.data});
  final int tab;
  final LbMyTournaments data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: switch (tab) {
        0 => _liveChildren(context, data),
        1 => _upcomingChildren(context, data),
        2 => _completedChildren(context, data),
        _ => const [SizedBox.shrink()],
      },
    );
  }

  List<Widget> _liveChildren(BuildContext context, LbMyTournaments d) {
    if (d.live.isEmpty) {
      return const [
        SizedBox(height: 60),
        _EmptyState(hint: 'No live tournaments right now.'),
      ];
    }
    return [
      for (final entry in d.live) ...[
        _LiveMatchReadyCard(
          entry: entry,
          onTap: () {
            final matchId = entry.currentMatchId;
            if (matchId == null) {
              context.push('/bracket/${entry.tournament.id}');
              return;
            }
            switch (entry.matchAction) {
              case LbMatchAction.submitResult:
                context.push('/submit-result/$matchId');
                return;
              case LbMatchAction.verifyResult:
                context.push('/verify-result/$matchId');
                return;
              case LbMatchAction.awaitingVerification:
              case LbMatchAction.none:
                context.push('/bracket/${entry.tournament.id}');
                return;
            }
          },
          onBracket: () => context.push('/bracket/${entry.tournament.id}'),
        ),
        const SizedBox(height: 14),
      ],
      if (d.upcoming.isNotEmpty) ...[
        SectionLabel('Upcoming', trailing: _CountTag('${d.upcoming.length}')),
        const SizedBox(height: 8),
        for (final u in d.upcoming) ...[
          _UpcomingRow(entry: u),
          const SizedBox(height: 8),
        ],
      ],
      if (d.completed.isNotEmpty) ...[
        const SectionLabel('Completed · Recent'),
        const SizedBox(height: 8),
        for (final c in d.completed) ...[
          _CompletedRow(entry: c),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  List<Widget> _upcomingChildren(BuildContext context, LbMyTournaments d) {
    if (d.upcoming.isEmpty) {
      return const [
        SizedBox(height: 60),
        _EmptyState(hint: 'No upcoming tournaments — hit Browse to find one.'),
      ];
    }
    return [
      for (final u in d.upcoming) ...[
        _UpcomingRow(entry: u),
        const SizedBox(height: 8),
      ],
    ];
  }

  List<Widget> _completedChildren(BuildContext context, LbMyTournaments d) {
    if (d.completed.isEmpty) {
      return const [
        SizedBox(height: 60),
        _EmptyState(hint: 'No completed tournaments yet.'),
      ];
    }
    return [
      for (final c in d.completed) ...[
        _CompletedRow(entry: c),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _CountTag extends StatelessWidget {
  const _CountTag(this.count);
  final String count;
  @override
  Widget build(BuildContext context) =>
      Text(count, style: LbType.metaSm.copyWith(color: LbColors.textDim));
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.value,
    required this.onChanged,
    required this.counts,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final (int, int, int) counts;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Live', counts.$1),
      ('Upcoming', counts.$2),
      ('Completed', counts.$3),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == i ? LbColors.lime : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: value == i
                        ? [
                            BoxShadow(
                              color: LbColors.lime.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: -4,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tabs[i].$1,
                        style: LbType.cardTitleSm.copyWith(
                          color: value == i
                              ? LbColors.limeInk
                              : LbColors.textSecondary,
                          fontSize: 11.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${tabs[i].$2}',
                        style: LbType.metaSm.copyWith(
                          color: value == i
                              ? LbColors.limeInk.withValues(alpha: 0.7)
                              : LbColors.textDim,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveMatchReadyCard extends StatelessWidget {
  const _LiveMatchReadyCard({
    required this.entry,
    required this.onTap,
    required this.onBracket,
  });

  final LbLiveEntry entry;
  final VoidCallback onTap;
  final VoidCallback onBracket;

  @override
  Widget build(BuildContext context) {
    final t = entry.tournament;
    final actionLabel = switch (entry.matchAction) {
      LbMatchAction.submitResult => 'Submit result ›',
      LbMatchAction.verifyResult => 'Review result ›',
      LbMatchAction.awaitingVerification => 'Awaiting review',
      LbMatchAction.none => 'View bracket',
    };
    final statusLabel = switch (entry.matchAction) {
      LbMatchAction.verifyResult => 'REVIEW NEEDED',
      LbMatchAction.awaitingVerification => 'UNDER REVIEW',
      LbMatchAction.submitResult => 'READY NOW',
      LbMatchAction.none => 'QUEUED',
    };
    return LbCard(
      highlighted: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 66,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GameArt(
                    game: t.game,
                    width: double.infinity,
                    height: 66,
                    radius: 0,
                    showLabel: false,
                  ),
                  Positioned(
                    top: 8,
                    left: 10,
                    child: Row(
                      children: [
                        const StatusPill.live(),
                        const SizedBox(width: 6),
                        LbChip(entry.currentBracketNode),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.title,
                            style: LbType.cardTitle.copyWith(
                              color: LbColors.textPrimaryHi,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          t.game,
                          style: LbType.metaSm.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const TeamAvatar(code: 'MNL'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: LbType.cardTitleSm,
                            children: [
                              const TextSpan(text: 'Team MNL '),
                              TextSpan(
                                text: 'vs Cebu Kings',
                                style: LbType.metaSm.copyWith(
                                  color: LbColors.textMuted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: LbType.metaSm.copyWith(
                          color: entry.matchReady
                              ? LbColors.lime
                              : LbColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SlantButton(
                          label: actionLabel,
                          onPressed: onTap,
                          height: 40,
                          notch: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GhostButton(
                        label: 'Bracket',
                        onPressed: onBracket,
                        height: 40,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.entry});
  final LbUpcomingEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = entry.tournament;
    final hot = entry.locksIn < const Duration(hours: 6);
    return LbCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/tournament/${t.id}'),
      child: Row(
        children: [
          GameArt(game: t.game, width: 56, height: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: LbType.cardTitleSm),
                Text(
                  '${t.game} · ${t.tier.displayName.toUpperCase()}',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'LOCKS IN',
                      style: LbType.metaSm.copyWith(
                        color: LbColors.textDim,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _countdown(entry.locksIn),
                      style: LbType.metaSm.copyWith(
                        color: hot ? LbColors.danger : LbColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          LbChip(t.tier.displayName, tone: t.tier.chipTone),
        ],
      ),
    );
  }
}

String _countdown(Duration d) {
  if (d.inDays > 0) {
    return '${d.inDays}d ${(d.inHours % 24).toString().padLeft(2, '0')}h';
  }
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.entry});
  final LbCompletedTournament entry;

  @override
  Widget build(BuildContext context) {
    final won = entry.wasWin;
    return LbCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/tournament/${entry.tournament.id}'),
      child: Row(
        children: [
          RankHex(
            rank: entry.finalPlace,
            size: 40,
            color: won ? LbColors.lime : LbColors.textDim,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.tournament.title, style: LbType.cardTitleSm),
                const SizedBox(height: 3),
                RichText(
                  text: TextSpan(
                    style: LbType.metaSm.copyWith(
                      color: LbColors.textMuted,
                      fontSize: 9.5,
                    ),
                    children: [
                      TextSpan(
                        text: won
                            ? 'WON · 1ST PLACE'
                            : 'OUT · ${_ordinal(entry.finalPlace)}',
                      ),
                      if (won)
                        TextSpan(
                          text: ' · +1 WIN → RANK',
                          style: LbType.metaSm.copyWith(
                            color: LbColors.lime,
                            fontSize: 9.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.tournament.usesWallet ? 'REWARD' : 'PAYOUT',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 9,
                ),
              ),
              Text(
                entry.tournament.usesWallet
                    ? '${entry.rewardPoints} VP'
                    : formatPeso(entry.payoutPhp, decimals: 0),
                style: LbType.rankNumeral(15, color: LbColors.lime),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _ordinal(int n) => switch (n) {
  1 => '1ST',
  2 => '2ND',
  3 => '3RD',
  _ => 'SEMIS',
};

// ── States ─────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
      height: h,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [block(180), block(64), block(64), block(64)],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 32,
            color: LbColors.textDim,
          ),
          const SizedBox(height: 8),
          Text(
            'NOTHING HERE YET',
            style: LbType.metaLabel.copyWith(
              color: LbColors.textMuted,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: LbType.bodySm.copyWith(color: LbColors.textDim),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: LbColors.danger,
          ),
          const SizedBox(height: 8),
          Text(message, style: LbType.bodySm),
          const SizedBox(height: 12),
          GhostButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}
