import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/fixtures.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../../core/widgets/team_avatar.dart';

/// MVP screen #5 — Bracket view.
///
/// Consumes [bracketProvider(tournamentId)] — a StreamProvider.autoDispose.
/// autoDispose closes the Supabase Realtime channel as soon as the user
/// navigates away, satisfying spec §9.3 (per-tournament scope, immediate
/// unsubscribe).
class BracketViewScreen extends ConsumerWidget {
  const BracketViewScreen({required this.tournamentId, super.key});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bracketProvider(tournamentId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Bracket'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                async.hasValue ? 'LIVE · SUBSCRIBED' : '…',
                style: LbType.metaSm.copyWith(
                  color: async.hasValue ? LbColors.lime : LbColors.textDim,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const _Skeleton(),
        error: (err, _) => _ErrorState(
          message: 'Lost realtime connection',
          onRetry: () => ref.invalidate(bracketProvider(tournamentId)),
        ),
        data: (bracket) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            const SectionLabel('Upper bracket'),
            const SizedBox(height: 8),
            if (bracket.upper.isEmpty)
              _EmptyRail(hint: 'No upper-bracket matches yet.')
            else
              for (final m in bracket.upper) _MatchRow(match: m),
            const SizedBox(height: 20),
            const SectionLabel('Lower bracket'),
            const SizedBox(height: 8),
            if (bracket.lower.isEmpty)
              _EmptyRail(hint: 'Nothing in the lower bracket yet.')
            else
              for (final m in bracket.lower) _MatchRow(match: m),
            const SizedBox(height: 20),
            const SectionLabel('Grand final'),
            const SizedBox(height: 8),
            _MatchRow(match: bracket.grandFinal, pendingIfNull: true),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({this.match, this.pendingIfNull = false});
  final LbMatch? match;
  final bool pendingIfNull;

  @override
  Widget build(BuildContext context) {
    if (match == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LbCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(child: _Side.pending(code: 'TBD')),
              const SizedBox(width: 10),
              Text(
                'VS',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  letterSpacing: 1,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: _Side.pending(code: 'TBD', reverse: true)),
            ],
          ),
        ),
      );
    }
    final m = match!;
    final live = !m.isPending && !m.isVerified;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LbCard(
        highlighted: live,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _Side(
                code: _teamCode(m.teamAId),
                score: m.scoreA,
                winner: m.isVerified && m.winnerId == m.teamAId,
                pending: m.isPending,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'VS',
              style: LbType.metaSm.copyWith(
                color: LbColors.textDim,
                letterSpacing: 1,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Side(
                code: _teamCode(m.teamBId),
                score: m.scoreB,
                winner: m.isVerified && m.winnerId == m.teamBId,
                pending: m.isPending,
                reverse: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _teamCode(String id) {
    if (id == LbFixtures.teamMnl.id) return LbFixtures.teamMnl.tag;
    if (id == LbFixtures.teamCebuKings.id) return LbFixtures.teamCebuKings.tag;
    if (id == LbFixtures.teamDavaoGg.id) return LbFixtures.teamDavaoGg.tag;
    return id.substring(id.length - 3).toUpperCase();
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.code,
    required this.score,
    required this.winner,
    required this.pending,
    this.reverse = false,
  });

  const _Side.pending({required this.code, this.reverse = false})
    : score = 0,
      winner = false,
      pending = true;

  final String code;
  final int score;
  final bool winner;
  final bool pending;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final avatar = TeamAvatar(code: code);
    final scoreText = Text(
      pending ? '—' : '$score',
      style: LbType.rankNumeral(
        20,
        color: winner ? LbColors.lime : LbColors.textPrimary,
      ),
    );
    return Row(
      mainAxisAlignment: reverse
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: reverse
          ? [scoreText, const SizedBox(width: 8), avatar]
          : [avatar, const SizedBox(width: 8), scoreText],
    );
  }
}

class _EmptyRail extends StatelessWidget {
  const _EmptyRail({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        hint,
        style: LbType.bodySm.copyWith(color: LbColors.textMuted),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block() => Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [block(), block(), block(), block()],
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
          GhostButton(label: 'Reconnect', onPressed: onRetry),
        ],
      ),
    );
  }
}
