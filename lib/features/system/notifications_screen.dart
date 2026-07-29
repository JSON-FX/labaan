import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/fixtures.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/data/repos.dart';
import '../../core/domain/ranks.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/rank_hex.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../../core/widgets/team_avatar.dart';

/// System · 2A · Notifications.
///
/// Consumes [notificationsProvider] as a stream so accept/decline on the
/// team-invite card removes the item optimistically without reloading.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    final userId = user.id;
    final feed = ref.watch(notificationsProvider(userId));
    final repo = ref.read(notificationsRepoProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => repo.markAllRead(userId),
            child: Text(
              'MARK ALL',
              style: LbType.metaSm.copyWith(
                color: LbColors.lime,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const _NotifSkeleton(),
        error: (err, _) => _ErrorState(
          message: 'Could not load notifications',
          onRetry: () => ref.invalidate(notificationsProvider(userId)),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          final today = <LbNotification>[];
          final earlier = <LbNotification>[];
          final cutoff = LbFixtures.now.subtract(const Duration(hours: 24));
          for (final n in items) {
            (n.createdAt.isAfter(cutoff) ? today : earlier).add(n);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (today.isNotEmpty) ...[
                const SectionLabel('Today'),
                const SizedBox(height: 8),
                for (final n in today) ...[
                  _NotifTile(notification: n, repo: repo),
                  const SizedBox(height: 8),
                ],
              ],
              if (earlier.isNotEmpty) ...[
                const SizedBox(height: 6),
                const SectionLabel('Earlier'),
                const SizedBox(height: 8),
                for (final n in earlier) ...[
                  _NotifTile(notification: n, repo: repo),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A single notification card. Renders based on [NotifKind] — match-ready
/// gets the highlighted lime treatment, team-invite gets inline accept /
/// decline buttons, dispute-opened routes straight to the dispute screen,
/// everything else is a muted "earlier" tile.
class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notification, required this.repo});

  final LbNotification notification;
  final NotificationsRepoActions repo;

  bool get _isPrimary =>
      (notification.kind == NotifKind.matchReady ||
          notification.kind == NotifKind.disputeOpened) &&
      !notification.isRead;

  @override
  Widget build(BuildContext context) {
    if (notification.kind == NotifKind.teamInvite) {
      return _TeamInviteTile(notification: notification, repo: repo);
    }
    return GestureDetector(
      onTap: notification.deepLink == null
          ? null
          : () => context.push(notification.deepLink!),
      behavior: HitTestBehavior.opaque,
      child: _StandardTile(notification: notification, primary: _isPrimary),
    );
  }
}

/// Just a typedef for what a NotificationsRepo exposes — keeps the tiles
/// decoupled from the whole repo surface.
typedef NotificationsRepoActions = NotificationsRepo;

class _StandardTile extends StatelessWidget {
  const _StandardTile({required this.notification, required this.primary});

  final LbNotification notification;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KindIcon(kind: notification.kind),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(notification.title, style: LbType.cardTitleSm),
                  ),
                  Text(
                    _relative(notification.createdAt),
                    style: LbType.metaSm.copyWith(
                      color: LbColors.textDim,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                notification.body,
                style: LbType.bodyXs.copyWith(
                  color: primary ? LbColors.textSecondary : LbColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (primary) {
      final isDanger = notification.kind == NotifKind.disputeOpened;
      if (isDanger) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LbColors.danger.withValues(alpha: 0.08),
            border: Border.all(color: LbColors.danger),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: LbColors.danger.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: -6,
              ),
            ],
          ),
          child: content,
        );
      }
      return LbCard(
        highlighted: true,
        padding: const EdgeInsets.all(12),
        child: content,
      );
    }
    return Opacity(
      opacity: notification.isRead ? 0.88 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notification.isRead ? LbColors.bgAlt : LbColors.surface,
          border: Border.all(
            color: notification.isRead ? LbColors.borderMuted : LbColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: content,
      ),
    );
  }
}

class _TeamInviteTile extends StatelessWidget {
  const _TeamInviteTile({required this.notification, required this.repo});
  final LbNotification notification;
  final NotificationsRepoActions repo;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TeamAvatar(code: 'CBU', size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: LbType.cardTitleSm,
                          ),
                        ),
                        Text(
                          _relative(notification.createdAt),
                          style: LbType.metaSm.copyWith(
                            color: LbColors.textDim,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: LbType.bodyXs.copyWith(
                        color: LbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SlantButton(
                  label: 'Accept',
                  onPressed: () => repo.respondToTeamInvite(
                    notificationId: notification.id,
                    accept: true,
                  ),
                  height: 34,
                  notch: 6,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GhostButton(
                  label: 'Decline',
                  onPressed: () => repo.respondToTeamInvite(
                    notificationId: notification.id,
                    accept: false,
                  ),
                  height: 34,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});
  final NotifKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case NotifKind.matchReady:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: LbColors.lime,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: LbColors.limeInk,
            size: 18,
          ),
        );
      case NotifKind.rankUp:
        return RankHex(
          rank: Rank.champion.level,
          size: 30,
          color: rankAccent(Rank.champion),
        );
      case NotifKind.badgeEarned:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A3A1A), LbColors.gold],
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.star_rounded,
            color: LbColors.limeInk,
            size: 18,
          ),
        );
      case NotifKind.resultVerified:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: LbColors.mlbbStart,
            border: Border.all(color: LbColors.border),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.check, color: LbColors.lime, size: 16),
        );
      case NotifKind.startingSoon:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF2A1A3E),
            border: Border.all(color: LbColors.border),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.schedule_rounded,
            color: LbColors.textSecondary,
            size: 16,
          ),
        );
      case NotifKind.disputeOpened:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: LbColors.danger.withValues(alpha: 0.15),
            border: Border.all(color: LbColors.danger),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.gavel_rounded,
            color: LbColors.danger,
            size: 16,
          ),
        );
      case NotifKind.payoutReceived:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: LbColors.lime.withValues(alpha: 0.12),
            border: Border.all(color: LbColors.lime),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.payments_rounded,
            color: LbColors.lime,
            size: 16,
          ),
        );
      case NotifKind.teamInvite:
        return const TeamAvatar(code: 'CBU', size: 30);
    }
  }
}

class _NotifSkeleton extends StatelessWidget {
  const _NotifSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, _) => Container(
        height: 68,
        decoration: BoxDecoration(
          color: LbColors.surface,
          border: Border.all(color: LbColors.borderMuted),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 32,
            color: LbColors.textDim,
          ),
          const SizedBox(height: 8),
          Text(
            'ALL CAUGHT UP',
            style: LbType.metaLabel.copyWith(
              color: LbColors.textMuted,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New alerts will land here.',
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

String _relative(DateTime dt) {
  final diff = LbFixtures.now.difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'yday';
  return '${diff.inDays}d';
}
