import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/tournament_tier.dart';
import '../../core/links/tournament_link_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/game_art.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/lb_chip.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';

/// MVP screen #3 — Tournament detail.
///
/// Fetches by id via [tournamentByIdProvider]. Every metric/label derives
/// from the [LbTournament] so it reflects real DB state.
typedef TournamentShareCallback =
    Future<void> Function(LbTournament tournament, Rect origin);

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({
    required this.slug,
    this.shareTournament,
    super.key,
  });

  final String slug;
  final TournamentShareCallback? shareTournament;

  Future<void> _share(LbTournament tournament, Rect origin) async {
    if (shareTournament != null) {
      await shareTournament!(tournament, origin);
      return;
    }
    final link = tournamentShareUri(tournament.id);
    await SharePlus.instance.share(
      ShareParams(
        title: tournament.title,
        subject: 'Join ${tournament.title} on Labaan',
        text:
            'Join ${tournament.title} on Labaan. '
            '${tournament.game} · ${formatPeso(tournament.prizePoolPhp, decimals: 0)} prize pool\n$link',
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tournamentByIdProvider(slug));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Tournament'),
        actions: [
          Builder(
            builder: (actionContext) => IconButton(
              key: const Key('share-tournament'),
              tooltip: 'Share tournament',
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              onPressed: async.value == null
                  ? null
                  : () async {
                      final box =
                          actionContext.findRenderObject() as RenderBox?;
                      final origin = box == null
                          ? Rect.zero
                          : box.localToGlobal(Offset.zero) & box.size;
                      try {
                        await _share(async.requireValue, origin);
                      } catch (_) {
                        if (!actionContext.mounted) return;
                        ScaffoldMessenger.of(actionContext).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open the share sheet.'),
                          ),
                        );
                      }
                    },
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const _Skeleton(),
        error: (err, _) => _ErrorState(
          message: 'Could not load tournament',
          onRetry: () => ref.invalidate(tournamentByIdProvider(slug)),
        ),
        data: (t) => Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
                children: [
                  _HeroBanner(tournament: t),
                  const SizedBox(height: 14),
                  SectionLabel(
                    t.usesWallet
                        ? 'Rewards · Entry · Format'
                        : 'Prize · Fee · Format',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'PRIZE',
                          value: t.usesWallet
                              ? 'TBD'
                              : formatPeso(t.prizePoolPhp, decimals: 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          label: 'ENTRY',
                          value: t.usesWallet
                              ? '${t.entryCreditCost ?? 0} CR'
                              : formatPeso(t.entryFeePhp, decimals: 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          label: 'FORMAT',
                          value: _formatBadge(t.format.name),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SectionLabel('Organizer & moderator'),
                  const SizedBox(height: 8),
                  _ProfilePersonRow(
                    userId: t.organizerId,
                    role: 'ORGANIZER',
                    fallbackName: 'Tournament organizer',
                    meta:
                        '${t.gabPermitNumber ?? "GAB permit pending"} · ${t.tier.displayName}',
                  ),
                  const SizedBox(height: 8),
                  if (t.moderatorIds.isEmpty)
                    _PersonRow(
                      role: 'MODERATOR',
                      name: 'Unassigned',
                      meta: 'Assigned before lock',
                    )
                  else
                    for (final id in t.moderatorIds) ...[
                      _ProfilePersonRow(
                        userId: id,
                        role: 'MODERATOR',
                        fallbackName: 'Tournament moderator',
                        meta: '30m result SLA · 15m dispute',
                      ),
                      const SizedBox(height: 8),
                    ],
                  const SizedBox(height: 6),
                  const SectionLabel('Rules'),
                  const SizedBox(height: 8),
                  const _RulesList(),
                  const SizedBox(height: 14),
                  const SectionLabel('Mini bracket · preview'),
                  const SizedBox(height: 8),
                  const _MiniBracket(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RegisterCta(
                tournament: t,
                onPressed: () => context.push('/register/${t.id}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBadge(String snake) => switch (snake) {
  'doubleElimination' => 'DBL ELIM',
  'singleElimination' => 'SGL ELIM',
  'roundRobin' => 'R-ROBIN',
  _ => snake.toUpperCase(),
};

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.tournament});
  final LbTournament tournament;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameArt(
              game: tournament.game,
              width: double.infinity,
              height: 120,
              radius: 0,
              showLabel: false,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      LbChip(
                        tournament.tier.displayName,
                        tone: tournament.tier.chipTone,
                      ),
                      const SizedBox(width: 6),
                      LbChip(
                        tournament.status.displayName,
                        tone: LbChipTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(tournament.title, style: LbType.sectionTitle),
                  Text(
                    '${tournament.game} · ${tournament.format.displayName}',
                    style: LbType.metaSm.copyWith(color: LbColors.textMuted),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: LbType.metaSm.copyWith(color: LbColors.textDim, fontSize: 9),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: LbType.sectionTitle.copyWith(
              color: LbColors.lime,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePersonRow extends ConsumerWidget {
  const _ProfilePersonRow({
    required this.userId,
    required this.role,
    required this.fallbackName,
    required this.meta,
  });

  final String userId;
  final String role;
  final String fallbackName;
  final String meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(userId));
    return _PersonRow(
      role: role,
      name: profile.when(
        loading: () => 'Loading…',
        error: (_, _) => fallbackName,
        data: (value) => value.user.username,
      ),
      meta: meta,
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.role,
    required this.name,
    required this.meta,
  });
  final String role;
  final String name;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [LbColors.surfaceHi, LbColors.mlbbStart],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: LbColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textDim,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
                Text(name, style: LbType.cardTitleSm),
                Text(
                  meta,
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9,
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

class _RulesList extends StatelessWidget {
  const _RulesList();

  static const _rules = <String>[
    'All matches Bo3, upper-bracket final Bo5.',
    'Screenshot required on every result submission.',
    'Disputes must be raised within 15 minutes of submission.',
    'Roster locks at bracket generation. No mid-tournament subs.',
    'GAB-registered platform · skill-based · outside PAGCOR.',
  ];

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '· ',
                    style: TextStyle(color: LbColors.lime, height: 1.5),
                  ),
                  Expanded(child: Text(rule, style: LbType.bodySm)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniBracket extends StatelessWidget {
  const _MiniBracket();

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 96,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_tree_rounded,
                size: 26,
                color: LbColors.lime.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 6),
              Text(
                'BRACKET · GENERATES AT LOCK',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 9.5,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterCta extends StatelessWidget {
  const _RegisterCta({required this.tournament, required this.onPressed});
  final LbTournament tournament;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            LbColors.bg,
            LbColors.bg.withValues(alpha: 0.9),
            LbColors.bg.withValues(alpha: 0),
          ],
          stops: const [0.55, 0.9, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SlantButton(
              label: 'Register ›',
              onPressed: onPressed,
              trailing: Text(
                tournament.usesWallet
                    ? '${tournament.entryCreditCost ?? 0} CR'
                    : formatPeso(tournament.entryFeePhp, decimals: 0),
                style: LbType.button.copyWith(color: LbColors.limeInk),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: h,
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [block(180), block(72), block(64), block(160)],
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
