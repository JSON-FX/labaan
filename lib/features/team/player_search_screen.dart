import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/domain/ranks.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/lb_chip.dart';
import '../../core/widgets/rank_hex.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';

/// MVP screen #8 — Player search.
///
/// Reads [playerSearchProvider(PlayerSearchQuery)]. Min-rank chip and
/// free-agent toggle drive the query.
class PlayerSearchScreen extends ConsumerStatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  ConsumerState<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends ConsumerState<PlayerSearchScreen> {
  Rank _minRank = Rank.champion;
  bool _freeAgentsOnly = true;

  @override
  Widget build(BuildContext context) {
    final query = PlayerSearchQuery(
      minRank: _minRank,
      freeAgentsOnly: _freeAgentsOnly,
    );
    final async = ref.watch(playerSearchProvider(query));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Find players'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: LbColors.surface,
              border: Border.all(color: LbColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: LbColors.textDim),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search usernames',
                    style: LbType.bodySm.copyWith(color: LbColors.textDim),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _RankFilterRow(
            value: _minRank,
            onChanged: (r) => setState(() => _minRank = r),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _FreeAgentToggle(
                value: _freeAgentsOnly,
                onChanged: (v) => setState(() => _freeAgentsOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionLabel(
            _freeAgentsOnly
                ? 'Free agents · ${_minRank.displayName}+'
                : 'All players · ${_minRank.displayName}+',
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const _Skeleton(),
            error: (err, _) => _ErrorState(
              message: 'Search failed',
              onRetry: () => ref.invalidate(playerSearchProvider(query)),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return const _EmptyState(
                  hint: 'No players match. Loosen the filters.',
                );
              }
              return Column(
                children: [
                  for (final r in page.items) ...[
                    _PlayerCard(
                      handle: r.user.username,
                      rank: r.rank.rank,
                      wins: r.rank.totalWins,
                      region: r.user.region ?? 'PH',
                      games: r.games.join(' · '),
                      onTeam: !r.isFreeAgent,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RankFilterRow extends StatelessWidget {
  const _RankFilterRow({required this.value, required this.onChanged});
  final Rank value;
  final ValueChanged<Rank> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: Rank.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final r = Rank.values[i];
          final active = r == value;
          return GestureDetector(
            onTap: () => onChanged(r),
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
                '≥ ${r.displayName.toUpperCase()}',
                style: LbType.metaSm.copyWith(
                  color: active ? LbColors.limeInk : LbColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FreeAgentToggle extends StatelessWidget {
  const _FreeAgentToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? LbColors.lime : LbColors.surface,
          border: Border.all(color: value ? LbColors.lime : LbColors.border),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 14,
              color: value ? LbColors.limeInk : LbColors.textDim,
            ),
            const SizedBox(width: 4),
            Text(
              'FREE AGENTS ONLY',
              style: LbType.metaSm.copyWith(
                color: value ? LbColors.limeInk : LbColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.handle,
    required this.rank,
    required this.wins,
    required this.region,
    required this.games,
    this.onTeam = false,
  });

  final String handle;
  final Rank rank;
  final int wins;
  final String region;
  final String games;
  final bool onTeam;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(10),
      onTap: () {},
      child: Row(
        children: [
          RankHex(rank: rank.level, size: 40, color: rankAccent(rank)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(handle, style: LbType.cardTitleSm),
                    const SizedBox(width: 6),
                    if (onTeam)
                      const LbChip('ON TEAM', tone: LbChipTone.neutral)
                    else
                      const LbChip('FREE AGENT', tone: LbChipTone.lime),
                  ],
                ),
                Text(
                  '${rank.displayName.toUpperCase()} · $wins WINS · $region',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
                Text(
                  games,
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textDim,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          GhostButton(
            label: 'Invite',
            onPressed: onTeam ? null : () {},
            height: 30,
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block() => Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return Column(children: [for (var i = 0; i < 4; i++) block()]);
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
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
