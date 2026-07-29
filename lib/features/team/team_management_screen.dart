import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
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

/// MVP screen #9 — Team management.
///
/// Reads [teamByIdProvider] for the header, [teamMembersProvider] for the
/// roster (which pulls each member's full profile — rank, badges, etc.).
class TeamManagementScreen extends ConsumerWidget {
  const TeamManagementScreen({this.teamId = 't_mnl', super.key});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamByIdProvider(teamId));
    final membersAsync = ref.watch(teamMembersProvider(teamId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(teamAsync.value?.name ?? 'Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: () {},
          ),
        ],
      ),
      body: teamAsync.when(
        loading: () => const _Skeleton(),
        error: (err, _) => _ErrorState(
          message: 'Could not load team',
          onRetry: () => ref.invalidate(teamByIdProvider(teamId)),
        ),
        data: (team) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            _TeamHeader(team: team),
            const SizedBox(height: 16),
            SectionLabel('Roster · ${team.memberCount} of 5'),
            const SizedBox(height: 8),
            membersAsync.when(
              loading: () => const _RosterSkeleton(),
              error: (err, _) => _ErrorState(
                message: 'Could not load roster',
                onRetry: () => ref.invalidate(teamMembersProvider(teamId)),
              ),
              data: (members) => Column(
                children: [
                  for (final m in members) ...[
                    _RosterRow(
                      handle: m.user.username,
                      rank: m.rank.rank,
                      role: m.user.id == team.captainUserId
                          ? 'CAPTAIN · IGL'
                          : _roleFor(members.indexOf(m)),
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SlantButton(
              label: 'Find players',
              onPressed: () => context.push('/team/search'),
              leading: const Icon(
                Icons.search_rounded,
                color: LbColors.limeInk,
                size: 16,
              ),
            ),
            const SizedBox(height: 8),
            GhostButton(label: 'Invite by username', onPressed: () {}),
            const SizedBox(height: 20),
            const SectionLabel('Danger zone'),
            const SizedBox(height: 8),
            _LeaveTeamCard(
              onLeave: () async {
                final user = ref.read(currentUserProvider).value;
                if (user == null) return;
                await ref
                    .read(teamsRepoProvider)
                    .leaveTeam(teamId: teamId, userId: user.id);
                if (!context.mounted) return;
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _roles = ['SENTINEL', 'DUELIST', 'INITIATOR', 'CONTROLLER'];

  String _roleFor(int index) => _roles[index % _roles.length];
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});
  final LbTeam team;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          TeamAvatar(code: team.tag, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name, style: LbType.sectionTitle),
                Text(
                  'MANILA · VALORANT · MLBB',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9.5,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    LbChip('12 WINS', tone: LbChipTone.lime),
                    SizedBox(width: 6),
                    LbChip('CHAMPION AVG', tone: LbChipTone.gold),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.handle,
    required this.rank,
    required this.role,
  });

  final String handle;
  final Rank rank;
  final String role;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          RankHex(rank: rank.level, size: 34, color: rankAccent(rank)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(handle, style: LbType.cardTitleSm),
                Text(
                  '${rank.displayName.toUpperCase()} · $role',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert, color: LbColors.textDim, size: 18),
        ],
      ),
    );
  }
}

class _LeaveTeamCard extends StatelessWidget {
  const _LeaveTeamCard({required this.onLeave});
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      onTap: onLeave,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave team',
                  style: LbType.cardTitleSm.copyWith(color: LbColors.danger),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cannot leave a team while registered for an active tournament.',
                  style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: LbColors.danger, size: 20),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: h,
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [block(90), block(28), for (var i = 0; i < 5; i++) block(54)],
    );
  }
}

class _RosterSkeleton extends StatelessWidget {
  const _RosterSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row() => Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return Column(children: [for (var i = 0; i < 5; i++) row()]);
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
