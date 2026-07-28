import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/fixtures.dart';
import '../../core/data/providers.dart';
import '../../core/domain/ranks.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/lb_chip.dart';
import '../../core/widgets/rank_hex.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../../core/widgets/team_avatar.dart';

/// MVP screen #11 — Leaderboard.
///
/// Reads [topPlayersProvider] / [topTeamsProvider] filtered by `_game`.
/// Repo-side these read the Redis-cached materialized view (5m TTL) —
/// screen just consumes.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _mode = 0; // 0 players, 1 teams
  int _game = 0;

  static const _games = ['All games', 'MLBB', 'VALORANT', 'TEKKEN 8'];

  String? get _gameFilter => _game == 0 ? null : _games[_game];

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(currentUserProvider).value?.id ?? LbFixtures.me.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: _PlayerTeamToggle(
              value: _mode,
              onChanged: (v) => setState(() => _mode = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _games.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final active = _game == i;
                  return GestureDetector(
                    onTap: () => setState(() => _game = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? LbColors.lime : LbColors.surface,
                        border: Border.all(
                          color: active ? LbColors.lime : LbColors.border,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _games[i].toUpperCase(),
                        style: LbType.metaSm.copyWith(
                          color: active
                              ? LbColors.limeInk
                              : LbColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: _mode == 0
                ? _PlayerBoard(gameFilter: _gameFilter, meId: currentUserId)
                : _TeamBoard(gameFilter: _gameFilter),
          ),
        ],
      ),
    );
  }
}

class _PlayerBoard extends ConsumerWidget {
  const _PlayerBoard({required this.gameFilter, required this.meId});
  final String? gameFilter;
  final String meId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topPlayersProvider(gameFilter));
    return async.when(
      loading: () => const _Skeleton(),
      error: (err, _) => _ErrorState(
        message: 'Leaderboard cache miss',
        onRetry: () => ref.invalidate(topPlayersProvider(gameFilter)),
      ),
      data: (players) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          SectionLabel(
            'Season 1 · Rank players',
            trailing: Text(
              'CACHE · 5m TTL',
              style: LbType.metaSm.copyWith(
                color: LbColors.textDim,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (players.isEmpty)
            const _EmptyState(hint: 'No players ranked yet.'),
          for (final p in players) ...[
            _RankRow(
              position: p.position,
              name: p.user.username,
              meta:
                  '${p.rank.rank.displayName.toUpperCase()} · ${p.rank.totalWins} WINS',
              rank: p.rank.rank,
              isYou: p.user.id == meId,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _TeamBoard extends ConsumerWidget {
  const _TeamBoard({required this.gameFilter});
  final String? gameFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topTeamsProvider(gameFilter));
    return async.when(
      loading: () => const _Skeleton(),
      error: (err, _) => _ErrorState(
        message: 'Leaderboard cache miss',
        onRetry: () => ref.invalidate(topTeamsProvider(gameFilter)),
      ),
      data: (teams) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          SectionLabel(
            'Season 1 · Rank teams',
            trailing: Text(
              'CACHE · 5m TTL',
              style: LbType.metaSm.copyWith(
                color: LbColors.textDim,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (teams.isEmpty) const _EmptyState(hint: 'No teams ranked yet.'),
          for (final t in teams) ...[
            _TeamRankRow(
              position: t.position,
              code: t.team.tag,
              name: t.team.name,
              wins: t.wins,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _PlayerTeamToggle extends StatelessWidget {
  const _PlayerTeamToggle({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (i, label) in const [(0, 'Players'), (1, 'Teams')])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == i ? LbColors.lime : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    label,
                    style: LbType.cardTitleSm.copyWith(
                      color: value == i
                          ? LbColors.limeInk
                          : LbColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.position,
    required this.name,
    required this.meta,
    required this.rank,
    this.isYou = false,
  });

  final int position;
  final String name;
  final String meta;
  final Rank rank;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      highlighted: isYou,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '#$position',
              style: LbType.rankNumeral(14, color: LbColors.textDim),
            ),
          ),
          const SizedBox(width: 4),
          RankHex(rank: rank.level, size: 32, color: rankAccent(rank)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: LbType.cardTitleSm),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      const LbChip('YOU', tone: LbChipTone.lime),
                    ],
                  ],
                ),
                Text(
                  meta,
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamRankRow extends StatelessWidget {
  const _TeamRankRow({
    required this.position,
    required this.code,
    required this.name,
    required this.wins,
  });

  final int position;
  final String code;
  final String name;
  final int wins;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '#$position',
              style: LbType.rankNumeral(14, color: LbColors.textDim),
            ),
          ),
          const SizedBox(width: 4),
          TeamAvatar(code: code, size: 32),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: LbType.cardTitleSm)),
          Text('$wins', style: LbType.rankNumeral(15, color: LbColors.lime)),
          const SizedBox(width: 4),
          Text(
            'WINS',
            style: LbType.metaSm.copyWith(color: LbColors.textDim, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          hint,
          style: LbType.bodySm.copyWith(color: LbColors.textMuted),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block() => Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [for (var i = 0; i < 6; i++) block()],
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
