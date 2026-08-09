import 'dart:async';

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
  String _search = '';
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  static const _games = [
    'All games',
    'MLBB',
    'VALORANT',
    'TEKKEN 8',
    'COD Mobile',
    'PUBG',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _commitSearch(value),
    );
  }

  void _commitSearch(String value) {
    _searchDebounce?.cancel();
    final normalized = value.trim();
    if (normalized == _search || !mounted) return;
    setState(() => _search = normalized);
  }

  void _clearSearch() {
    _searchController.clear();
    _commitSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final query = BrowseQuery(
      game: _game == 'All games' ? null : _game,
      search: _search.isEmpty ? null : _search,
    );
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
            _SearchBar(
              controller: _searchController,
              onChanged: _scheduleSearch,
              onSubmitted: _commitSearch,
              onClear: _clearSearch,
            ),
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
                if (page.items.isEmpty) {
                  return _EmptyState(searchQuery: _search);
                }
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
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        key: const Key('browse-search'),
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: LbType.bodySm.copyWith(color: LbColors.textPrimary),
        cursorColor: LbColors.lime,
        decoration: InputDecoration(
          hintText: 'Search tournaments',
          hintStyle: LbType.bodySm.copyWith(color: LbColors.textDim),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: LbColors.textDim,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const Key('clear-browse-search'),
                    tooltip: 'Clear search',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
          filled: true,
          fillColor: LbColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: LbColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: LbColors.lime),
          ),
        ),
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
                    Expanded(
                      child: Text(
                        '${tournament.registeredTeams} / ${tournament.maxTeams} SLOTS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LbType.metaSm.copyWith(
                          color: LbColors.textDim,
                          fontSize: 9,
                        ),
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
                tournament.usesWallet
                    ? '${tournament.entryCreditCost ?? 0} CR'
                    : formatPeso(tournament.entryFeePhp, decimals: 0),
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
  const _EmptyState({required this.searchQuery});

  final String searchQuery;

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
            searchQuery.isEmpty
                ? 'Try another game or clear the filter.'
                : 'No open tournaments match “$searchQuery”.',
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
