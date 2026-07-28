import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/tournament_tier.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/game_art.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/lb_chip.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';

/// MVP screen #2 — Browse marketplace.
///
/// Consumes [browsePageProvider(BrowseQuery)]. Cursor pagination hook is
/// wired end-to-end at the repo layer; the UI shows the first page with an
/// affordance for "load more" once mocks return a nextCursor.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  String _game = 'All games';

  static const _games = [
    'All games',
    'MLBB',
    'VALORANT',
    'TEKKEN 8',
    'COD Mobile',
    'PUBG',
  ];

  @override
  Widget build(BuildContext context) {
    final query = BrowseQuery(game: _game == 'All games' ? null : _game);
    final async = ref.watch(browsePageProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        color: LbColors.lime,
        backgroundColor: LbColors.surface,
        onRefresh: () async {
          ref.invalidate(browsePageProvider(query));
          await ref.read(browsePageProvider(query).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            const _SearchBar(),
            const SizedBox(height: 12),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _games.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final active = _games[i] == _game;
                  return GestureDetector(
                    onTap: () => setState(() => _game = _games[i]),
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
            const SizedBox(height: 16),
            SectionLabel(
              'Open now',
              trailing: Text(
                'CURSOR-PAGINATED',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 9,
                ),
              ),
            ),
            const SizedBox(height: 10),
            async.when(
              loading: () => const _Skeleton(),
              error: (err, _) => _ErrorState(
                message: 'Could not load tournaments',
                onRetry: () => ref.invalidate(browsePageProvider(query)),
              ),
              data: (page) {
                if (page.items.isEmpty) return const _EmptyState();
                return Column(
                  children: [
                    for (final t in page.items) ...[
                      _TournamentBrowseRow(
                        tournament: t,
                        onTap: () => context.push('/tournament/${t.id}'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              'Search tournaments or organizers',
              style: LbType.bodySm.copyWith(color: LbColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentBrowseRow extends StatelessWidget {
  const _TournamentBrowseRow({required this.tournament, required this.onTap});
  final LbTournament tournament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        children: [
          GameArt(game: tournament.game, width: 56, height: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.title, style: LbType.cardTitleSm),
                Text(
                  '${tournament.game} · ${_formatShort(tournament.format.name)}',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    LbChip(
                      tournament.tier.displayName,
                      tone: tournament.tier.chipTone,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${tournament.registeredTeams} / ${tournament.maxTeams} SLOTS',
                      style: LbType.metaSm.copyWith(
                        color: LbColors.textDim,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ENTRY',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 9,
                ),
              ),
              Text(
                formatPeso(tournament.entryFeePhp, decimals: 0),
                style: LbType.rankNumeral(15, color: LbColors.lime),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatShort(String snake) => switch (snake) {
  'doubleElimination' => 'DBL ELIM',
  'singleElimination' => 'SGL ELIM',
  _ => snake.toUpperCase(),
};

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block() => Container(
      height: 66,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return Column(children: [block(), block(), block(), block()]);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 32,
            color: LbColors.textDim,
          ),
          const SizedBox(height: 8),
          Text(
            'NOTHING MATCHES',
            style: LbType.metaLabel.copyWith(
              color: LbColors.textMuted,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try another game or clear the filter.',
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
