import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/fixtures.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/data/repos.dart';
import '../../core/domain/ranks.dart';
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

/// Player App · 1A · Home Feed.
///
/// Static: greeting rail (reads current user) + quick actions.
/// Dynamic: live-now hero, featured tournaments, trending — all pulled from
/// [homeFeedForUserProvider] with loading / empty / error states.
class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);
    final user = userState.value;
    if (user == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    final userRank = ref.watch(profileByIdProvider(user.id)).value?.rank;
    final feed = ref.watch(homeFeedForUserProvider(user.id));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: LbColors.lime,
          backgroundColor: LbColors.surface,
          onRefresh: () async {
            ref.invalidate(homeFeedForUserProvider(user.id));
            await ref.read(homeFeedForUserProvider(user.id).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              _GreetingBar(user: user, rank: userRank),
              const SizedBox(height: 18),
              feed.when(
                loading: () => const _HomeFeedSkeleton(),
                error: (err, _) => _ErrorState(
                  message: 'Could not load your feed',
                  onRetry: () =>
                      ref.invalidate(homeFeedForUserProvider(user.id)),
                ),
                data: (data) => _HomeBody(data: data),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data});
  final LbHomeFeed data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.liveMatchReady != null) ...[
          _HeroLiveCard(
            tournament: data.liveMatchReady!,
            onTap: () => context.push('/submit-result'),
            onBracket: () =>
                context.push('/bracket/${data.liveMatchReady!.id}'),
          ),
          const SizedBox(height: 16),
        ],
        SectionLabel(
          'Featured for you',
          trailing: Text(
            'SEE ALL',
            style: LbType.metaSm.copyWith(
              color: LbColors.lime,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (data.featured.isEmpty)
          const _EmptyRail(hint: 'Nothing curated today.')
        else
          _FeaturedRail(items: data.featured),
        const SizedBox(height: 18),
        const SectionLabel('Quick actions'),
        const SizedBox(height: 10),
        const _QuickActions(),
        const SizedBox(height: 18),
        SectionLabel(
          'Trending in Manila',
          trailing: Text(
            'MLBB · VAL · TEKKEN',
            style: LbType.metaSm.copyWith(color: LbColors.textDim),
          ),
        ),
        const SizedBox(height: 10),
        if (data.trending.isEmpty)
          const _EmptyRow(hint: 'No trending tournaments right now.')
        else
          for (final t in data.trending) ...[
            _TrendingRow(
              tournament: t,
              onTap: () => context.push('/tournament/${t.id}'),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _GreetingBar extends StatelessWidget {
  const _GreetingBar({required this.user, required this.rank});
  final LbUser user;
  final LbUserRank? rank;

  @override
  Widget build(BuildContext context) {
    final rankLevel = rank?.rank.level ?? Rank.recruit.level;
    return Row(
      children: [
        RankHex(
          rank: rankLevel,
          size: 40,
          color: rankAccent(rank?.rank ?? Rank.recruit),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KUMUSTA, ${user.username}',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text('Ready to fight.', style: LbType.sectionTitle),
            ],
          ),
        ),
        _NotificationBell(userId: user.id),
      ],
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider(userId));
    final unread = notifs.when(
      data: (list) => list.any((n) => !n.isRead),
      loading: () => false,
      error: (_, _) => false,
    );
    return GestureDetector(
      onTap: () => context.push('/notifications'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: LbColors.surface,
          border: Border.all(color: LbColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.notifications_none_rounded,
                color: LbColors.textSecondary,
                size: 18,
              ),
            ),
            if (unread)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: LbColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroLiveCard extends StatelessWidget {
  const _HeroLiveCard({
    required this.tournament,
    required this.onTap,
    required this.onBracket,
  });
  final LbTournament tournament;
  final VoidCallback onTap;
  final VoidCallback onBracket;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      highlighted: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GameArt(
                    game: tournament.game,
                    width: double.infinity,
                    height: 130,
                    radius: 0,
                    showLabel: false,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: const [
                        StatusPill.live(),
                        SizedBox(width: 6),
                        LbChip('QUARTERFINAL · R2'),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.title,
                          style: LbType.sectionTitle.copyWith(
                            color: LbColors.textPrimaryHi,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${tournament.game} · Team MNL vs Cebu Kings',
                          style: LbType.metaSm.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 10,
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
              child: Row(
                children: [
                  Expanded(
                    child: SlantButton(
                      label: 'Match ready ›',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedRail extends StatelessWidget {
  const _FeaturedRail({required this.items});
  final List<LbTournament> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 182,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final t = items[i];
          final locksIn = t.countdownToLock(LbFixtures.now);
          return SizedBox(
            width: 220,
            child: LbCard(
              padding: EdgeInsets.zero,
              onTap: () => context.push('/tournament/${t.id}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GameArt(game: t.game, width: 220, height: 90, radius: 0),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LbType.cardTitleSm,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${t.game} · ${_formatFormat(t.format.name)}',
                            style: LbType.metaSm.copyWith(
                              color: LbColors.textMuted,
                              fontSize: 9.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              LbChip(t.tier.displayName, tone: t.tier.chipTone),
                              if (locksIn != null)
                                Text(
                                  'LOCKS ${_shortDuration(locksIn)}',
                                  style: LbType.metaSm.copyWith(
                                    color: locksIn.inHours < 6
                                        ? LbColors.danger
                                        : LbColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _formatFormat(String snake) => switch (snake) {
  'doubleElimination' => '5V5',
  'singleElimination' => '1V1',
  _ => snake.toUpperCase(),
};

String _shortDuration(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d';
  if (d.inHours > 0) {
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  }
  return '${d.inMinutes}m';
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = <(IconData, String, String)>[
    (Icons.emoji_events_rounded, 'HOST', '/host'),
    (Icons.groups_rounded, 'TEAM', '/team'),
    (Icons.wallet_rounded, 'WALLET', '/wallet'),
    (Icons.support_agent_rounded, 'SUPPORT', '/support'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: LbCard(
              padding: const EdgeInsets.symmetric(vertical: 12),
              onTap: () {
                final path = _actions[i].$3;
                if (path == '/team') context.push('/team');
              },
              child: Column(
                children: [
                  Icon(_actions[i].$1, color: LbColors.lime, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    _actions[i].$2,
                    style: LbType.metaSm.copyWith(
                      color: LbColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.tournament, required this.onTap});
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
                  '${tournament.game} · ${tournament.tier.displayName}',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tournament.registeredTeams} / ${tournament.maxTeams} PLAYERS',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textDim,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PRIZE',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 9,
                ),
              ),
              Text(
                formatPeso(tournament.prizePoolPhp, decimals: 0),
                style: LbType.rankNumeral(15, color: LbColors.lime),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── States ─────────────────────────────────────────────────────────────────

class _HomeFeedSkeleton extends StatelessWidget {
  const _HomeFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
      height: h,
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        block(180),
        const SizedBox(height: 16),
        block(28),
        const SizedBox(height: 10),
        SizedBox(
          height: 172,
          child: Row(
            children: [
              Expanded(child: block(172)),
              const SizedBox(width: 10),
              Expanded(child: block(172)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        block(28),
        const SizedBox(height: 10),
        block(64),
      ],
    );
  }
}

class _EmptyRail extends StatelessWidget {
  const _EmptyRail({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Center(
        child: Text(
          hint,
          style: LbType.bodySm.copyWith(color: LbColors.textMuted),
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 26,
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
