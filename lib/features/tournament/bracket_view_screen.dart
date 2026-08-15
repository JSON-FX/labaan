import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/data/repos.dart';
import '../../core/domain/tournament_status.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/team_avatar.dart';

/// Live tournament bracket grouped into horizontally scrolling round columns.
class BracketViewScreen extends ConsumerStatefulWidget {
  const BracketViewScreen({required this.tournamentId, super.key});

  final String tournamentId;

  @override
  ConsumerState<BracketViewScreen> createState() => _BracketViewScreenState();
}

class _BracketViewScreenState extends ConsumerState<BracketViewScreen> {
  _BracketSection _section = _BracketSection.upper;

  @override
  Widget build(BuildContext context) {
    final bracketAsync = ref.watch(bracketProvider(widget.tournamentId));
    final tournament = ref
        .watch(tournamentByIdProvider(widget.tournamentId))
        .value;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton.outlined(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () => context.pop(),
          ),
        ),
        leadingWidth: 58,
        title: Text(tournament?.title ?? 'Bracket View'),
        actions: [
          if (tournament?.status == TournamentStatus.live)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: _LiveBadge(),
            ),
        ],
      ),
      body: bracketAsync.when(
        loading: () => const _Skeleton(),
        error: (err, _) => _ErrorState(
          message: 'Lost realtime connection',
          onRetry: () => ref.invalidate(bracketProvider(widget.tournamentId)),
        ),
        data: (bracket) {
          final matches = _matchesFor(bracket, _section);
          final liveMatch = _firstActiveMatch(bracket);
          return Column(
            children: [
              _TournamentMeta(tournament: tournament),
              _BracketTabs(
                selected: _section,
                currentRound: _currentRound(matches),
                roundCount: _roundCount(matches),
                onSelected: (value) => setState(() => _section = value),
              ),
              Expanded(
                child: _RoundCanvas(
                  section: _section,
                  matches: matches,
                  teams: bracket.teams,
                ),
              ),
              if (liveMatch != null)
                _LiveMatchStrip(match: liveMatch, teams: bracket.teams),
            ],
          );
        },
      ),
    );
  }
}

enum _BracketSection { upper, lower, grandFinal }

List<LbMatch> _matchesFor(LbBracket bracket, _BracketSection section) =>
    switch (section) {
      _BracketSection.upper => bracket.upper,
      _BracketSection.lower => bracket.lower,
      _BracketSection.grandFinal => [
        if (bracket.grandFinal != null) bracket.grandFinal!,
      ],
    };

LbMatch? _firstActiveMatch(LbBracket bracket) {
  final matches =
      [
        ...bracket.upper,
        ...bracket.lower,
        if (bracket.grandFinal != null) bracket.grandFinal!,
      ]..sort((a, b) {
        final round = a.round.compareTo(b.round);
        return round != 0 ? round : a.position.compareTo(b.position);
      });
  return matches.where(_isActive).firstOrNull;
}

bool _isActive(LbMatch match) => switch (match.status) {
  LbMatchStatus.ready ||
  LbMatchStatus.awaitingResult ||
  LbMatchStatus.awaitingVerification ||
  LbMatchStatus.disputed => true,
  _ => false,
};

int _roundCount(List<LbMatch> matches) =>
    matches.map((match) => match.round).toSet().length;

int _currentRound(List<LbMatch> matches) {
  if (matches.isEmpty) return 0;
  final active = matches.where(_isActive).map((match) => match.round).toList();
  if (active.isNotEmpty) return active.reduce((a, b) => a < b ? a : b);
  final pending = matches
      .where((match) => match.status != LbMatchStatus.completed)
      .map((match) => match.round)
      .toList();
  if (pending.isNotEmpty) return pending.reduce((a, b) => a < b ? a : b);
  return matches.map((match) => match.round).reduce((a, b) => a > b ? a : b);
}

class _TournamentMeta extends StatelessWidget {
  const _TournamentMeta({required this.tournament});

  final LbTournament? tournament;

  @override
  Widget build(BuildContext context) {
    final value = tournament;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null
                  ? 'LIVE TOURNAMENT'
                  : '${value.game} · ${value.format.displayName.toUpperCase()} · '
                        '${value.registeredTeams} TEAMS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LbType.metaSm.copyWith(
                color: LbColors.textMuted,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Text(
            'LIVE · SUBSCRIBED',
            style: LbType.metaSm.copyWith(
              color: LbColors.lime,
              fontSize: 9,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: LbColors.danger,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text('LIVE', style: LbType.timerHot),
      ],
    );
  }
}

class _BracketTabs extends StatelessWidget {
  const _BracketTabs({
    required this.selected,
    required this.currentRound,
    required this.roundCount,
    required this.onSelected,
  });

  final _BracketSection selected;
  final int currentRound;
  final int roundCount;
  final ValueChanged<_BracketSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LbColors.borderMuted)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _BracketTab(
            label: 'UPPER',
            selected: selected == _BracketSection.upper,
            onTap: () => onSelected(_BracketSection.upper),
          ),
          _BracketTab(
            label: 'LOWER',
            selected: selected == _BracketSection.lower,
            onTap: () => onSelected(_BracketSection.lower),
          ),
          _BracketTab(
            label: 'GRAND FINAL',
            selected: selected == _BracketSection.grandFinal,
            onTap: () => onSelected(_BracketSection.grandFinal),
          ),
          const Spacer(),
          Text(
            currentRound == 0 ? '—' : 'R$currentRound / $roundCount',
            style: LbType.metaSm.copyWith(
              color: LbColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketTab extends StatelessWidget {
  const _BracketTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 13, 8, 11),
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? LbColors.lime : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: LbType.metaSm.copyWith(
            color: selected ? LbColors.lime : LbColors.textDim,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoundCanvas extends StatelessWidget {
  const _RoundCanvas({
    required this.section,
    required this.matches,
    required this.teams,
  });

  final _BracketSection section;
  final List<LbMatch> matches;
  final Map<String, LbTeam> teams;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return _EmptyBracket(section: section);

    final rounds = <int, List<LbMatch>>{};
    for (final match in matches) {
      rounds.putIfAbsent(match.round, () => []).add(match);
    }
    final roundNumbers = rounds.keys.toList()..sort();
    for (final values in rounds.values) {
      values.sort((a, b) => a.position.compareTo(b.position));
    }

    return Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 18, 20, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < roundNumbers.length; i++) ...[
                _RoundColumn(
                  round: roundNumbers[i],
                  matches: rounds[roundNumbers[i]]!,
                  teams: teams,
                  section: section,
                  cardOffset: i * 52,
                ),
                if (i != roundNumbers.length - 1) const SizedBox(width: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({
    required this.round,
    required this.matches,
    required this.teams,
    required this.section,
    required this.cardOffset,
  });

  final int round;
  final List<LbMatch> matches;
  final Map<String, LbTeam> teams;
  final _BracketSection section;
  final int cardOffset;

  @override
  Widget build(BuildContext context) {
    final active = matches.any(_isActive);
    final complete = matches.every(
      (match) => match.status == LbMatchStatus.completed,
    );
    return SizedBox(
      width: 224,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              'R$round  ·  ${active
                  ? "LIVE NOW"
                  : complete
                  ? "DONE"
                  : "UP NEXT"}',
              style: LbType.metaSm.copyWith(
                color: active
                    ? LbColors.lime
                    : complete
                    ? LbColors.textDim
                    : LbColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.4,
              ),
            ),
          ),
          SizedBox(height: cardOffset.toDouble()),
          for (final match in matches) ...[
            _MatchCard(match: match, teams: teams, section: section),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.teams,
    required this.section,
  });

  final LbMatch match;
  final Map<String, LbTeam> teams;
  final _BracketSection section;

  @override
  Widget build(BuildContext context) {
    final active = _isActive(match);
    final complete = match.status == LbMatchStatus.completed;
    final sideLabel = switch (section) {
      _BracketSection.upper => 'UB',
      _BracketSection.lower => 'LB',
      _BracketSection.grandFinal => 'GF',
    };
    return Opacity(
      opacity: complete ? 0.68 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: active
              ? LbColors.lime.withValues(alpha: 0.055)
              : LbColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? LbColors.lime : LbColors.border,
            width: active ? 1.7 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: LbColors.lime.withValues(alpha: 0.28),
                    blurRadius: 20,
                    spreadRadius: -7,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'M${match.position} · $sideLabel',
                      style: LbType.metaSm.copyWith(
                        color: active ? LbColors.lime : LbColors.textDim,
                        fontSize: 9,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  _MatchStatusLabel(match: match),
                ],
              ),
            ),
            const Divider(height: 1, color: LbColors.borderMuted),
            _TeamLine(
              team: teams[match.teamAId],
              score: match.scoreA,
              showScore: complete || match.scoreA > 0,
              winner: match.winnerId == match.teamAId,
            ),
            const Divider(height: 1, color: LbColors.borderMuted),
            _TeamLine(
              team: teams[match.teamBId],
              score: match.scoreB,
              showScore: complete || match.scoreB > 0,
              winner: match.winnerId == match.teamBId,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchStatusLabel extends StatelessWidget {
  const _MatchStatusLabel({required this.match});

  final LbMatch match;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (match.status) {
      LbMatchStatus.awaitingResult => ('● LIVE', LbColors.danger),
      LbMatchStatus.ready => ('READY', LbColors.lime),
      LbMatchStatus.awaitingVerification => ('VERIFY', LbColors.gold),
      LbMatchStatus.disputed => ('DISPUTED', LbColors.danger),
      LbMatchStatus.completed => ('DONE', LbColors.textDim),
      LbMatchStatus.pending => ('UP NEXT', LbColors.textDim),
    };
    return Text(
      label,
      style: LbType.metaSm.copyWith(
        color: color,
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({
    required this.team,
    required this.score,
    required this.showScore,
    required this.winner,
  });

  final LbTeam? team;
  final int score;
  final bool showScore;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final code = team?.tag ?? 'TBD';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          TeamAvatar(code: code, size: 25),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              team?.name ?? 'To be determined',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LbType.cardTitleSm.copyWith(
                color: team == null ? LbColors.textDim : LbColors.textPrimary,
              ),
            ),
          ),
          Text(
            showScore ? '$score' : '—',
            style: LbType.rankNumeral(
              18,
              color: winner ? LbColors.lime : LbColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMatchStrip extends StatelessWidget {
  const _LiveMatchStrip({required this.match, required this.teams});

  final LbMatch match;
  final Map<String, LbTeam> teams;

  @override
  Widget build(BuildContext context) {
    final teamA = teams[match.teamAId]?.tag ?? 'TBD';
    final teamB = teams[match.teamBId]?.tag ?? 'TBD';
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: LbColors.bgAlt,
          border: Border(top: BorderSide(color: LbColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 42,
              decoration: BoxDecoration(
                color: LbColors.lime,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE MATCH · R${match.round}',
                    style: LbType.metaSm.copyWith(
                      color: LbColors.textDim,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('$teamA  VS  $teamB', style: LbType.cardTitle),
                ],
              ),
            ),
            const _LiveBadge(),
          ],
        ),
      ),
    );
  }
}

class _EmptyBracket extends StatelessWidget {
  const _EmptyBracket({required this.section});

  final _BracketSection section;

  @override
  Widget build(BuildContext context) {
    final label = switch (section) {
      _BracketSection.upper => 'upper-bracket matches',
      _BracketSection.lower => 'lower-bracket matches',
      _BracketSection.grandFinal => 'a grand final',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No $label yet.',
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
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(height: 42, color: LbColors.surface),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              Expanded(
                child: Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: LbColors.surface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
              if (i == 0) const SizedBox(width: 12),
            ],
          ],
        ),
      ],
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
          const Icon(Icons.wifi_off_rounded, size: 32, color: LbColors.danger),
          const SizedBox(height: 8),
          Text(message, style: LbType.bodySm),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('RECONNECT')),
        ],
      ),
    );
  }
}
