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
  const TeamManagementScreen({this.teamId, super.key});

  final String? teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final resolvedTeamId = teamId;
    if (resolvedTeamId == null) {
      if (currentUser == null) {
        return const Scaffold(body: _Skeleton());
      }
      final teamsAsync = ref.watch(teamsForUserProvider(currentUser.id));
      return teamsAsync.when(
        loading: () => const Scaffold(body: _Skeleton()),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Team')),
          body: _ErrorState(
            message: 'Could not load your teams',
            onRetry: () => ref.invalidate(teamsForUserProvider(currentUser.id)),
          ),
        ),
        data: (teams) => teams.isEmpty
            ? Scaffold(
                appBar: AppBar(title: const Text('Team')),
                body: Center(
                  child: Text(
                    'You are not on a team yet.',
                    style: LbType.bodySm.copyWith(color: LbColors.textMuted),
                  ),
                ),
              )
            : TeamManagementScreen(teamId: teams.first.id),
      );
    }
    final teamAsync = ref.watch(teamByIdProvider(resolvedTeamId));
    final membersAsync = ref.watch(teamMembersProvider(resolvedTeamId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(teamAsync.value?.name ?? 'Team'),
        actions: [
          if (teamAsync.value != null &&
              currentUser?.id == teamAsync.value!.captainUserId)
            IconButton(
              key: const Key('edit-team'),
              tooltip: 'Edit team',
              icon: const Icon(Icons.edit_rounded, size: 18),
              onPressed: () async {
                final updated = await showDialog<bool>(
                  context: context,
                  builder: (_) => _EditTeamDialog(team: teamAsync.value!),
                );
                if (updated != true || !context.mounted) return;
                ref.invalidate(teamByIdProvider(resolvedTeamId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team identity updated.')),
                );
              },
            ),
        ],
      ),
      body: teamAsync.when(
        loading: () => const _Skeleton(),
        error: (err, _) => _ErrorState(
          message: 'Could not load team',
          onRetry: () => ref.invalidate(teamByIdProvider(resolvedTeamId)),
        ),
        data: (team) {
          final canManage = currentUser?.id == team.captainUserId;
          return ListView(
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
                  onRetry: () =>
                      ref.invalidate(teamMembersProvider(resolvedTeamId)),
                ),
                data: (members) => Column(
                  children: [
                    for (final m in members) ...[
                      _RosterRow(
                        userId: m.user.id,
                        handle: m.user.username,
                        rank: m.rank.rank,
                        role: m.user.id == team.captainUserId
                            ? 'CAPTAIN · IGL'
                            : _roleFor(members.indexOf(m)),
                        canManage: canManage && m.user.id != team.captainUserId,
                        onPromote: () => _manageMember(
                          context: context,
                          ref: ref,
                          teamId: resolvedTeamId,
                          userId: m.user.id,
                          username: m.user.username,
                          transferCaptain: true,
                        ),
                        onRemove: () => _manageMember(
                          context: context,
                          ref: ref,
                          teamId: resolvedTeamId,
                          userId: m.user.id,
                          username: m.user.username,
                          transferCaptain: false,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              if (canManage) ...[
                const SizedBox(height: 16),
                SlantButton(
                  label: 'Find players',
                  onPressed: () => context.push(
                    Uri(
                      path: '/team/search',
                      queryParameters: {'teamId': resolvedTeamId},
                    ).toString(),
                  ),
                  leading: const Icon(
                    Icons.search_rounded,
                    color: LbColors.limeInk,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 8),
                GhostButton(
                  label: 'Invite by username',
                  onPressed: () async {
                    final sent = await showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          _InviteByUsernameDialog(teamId: resolvedTeamId),
                    );
                    if (sent != true || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Team invitation sent.')),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              const SectionLabel('Danger zone'),
              const SizedBox(height: 8),
              _LeaveTeamCard(
                isCaptain: canManage,
                onLeave: () async {
                  final user = ref.read(currentUserProvider).value;
                  if (user == null) return;
                  final confirmed = await _confirmAction(
                    context,
                    title: 'Leave team?',
                    message: 'You will need another invitation to rejoin.',
                    confirmLabel: 'Leave team',
                    destructive: true,
                  );
                  if (!confirmed || !context.mounted) return;
                  try {
                    await ref
                        .read(teamsRepoProvider)
                        .leaveTeam(teamId: resolvedTeamId, userId: user.id);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_teamManageErrorMessage(error))),
                    );
                    return;
                  }
                  if (!context.mounted) return;
                  context.pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static const _roles = ['SENTINEL', 'DUELIST', 'INITIATOR', 'CONTROLLER'];

  String _roleFor(int index) => _roles[index % _roles.length];
}

Future<void> _manageMember({
  required BuildContext context,
  required WidgetRef ref,
  required String teamId,
  required String userId,
  required String username,
  required bool transferCaptain,
}) async {
  final confirmed = await _confirmAction(
    context,
    title: transferCaptain ? 'Make $username captain?' : 'Remove $username?',
    message: transferCaptain
        ? 'You will become a regular member and lose captain controls.'
        : 'They will need another invitation to rejoin.',
    confirmLabel: transferCaptain ? 'Transfer captaincy' : 'Remove member',
    destructive: !transferCaptain,
  );
  if (!confirmed || !context.mounted) return;
  try {
    final repo = ref.read(teamsRepoProvider);
    if (transferCaptain) {
      await repo.transferCaptain(teamId: teamId, userId: userId);
    } else {
      await repo.removeMember(teamId: teamId, userId: userId);
    }
    ref.invalidate(teamByIdProvider(teamId));
    ref.invalidate(teamMembersProvider(teamId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          transferCaptain
              ? '$username is now team captain.'
              : '$username was removed from the team.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_teamManageErrorMessage(error))));
  }
}

Future<bool> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm-team-action'),
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: LbColors.danger)
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

class _EditTeamDialog extends ConsumerStatefulWidget {
  const _EditTeamDialog({required this.team});

  final LbTeam team;

  @override
  ConsumerState<_EditTeamDialog> createState() => _EditTeamDialogState();
}

class _EditTeamDialogState extends ConsumerState<_EditTeamDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _tagController;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team.name);
    _tagController = TextEditingController(text: widget.team.tag);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final tag = _tagController.text.trim();
    if (name.length < 3 || name.length > 50) {
      setState(() => _error = 'Team name must be 3–50 characters.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9]{2,5}$').hasMatch(tag)) {
      setState(() => _error = 'Tag must be 2–5 letters or numbers.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(teamsRepoProvider)
          .updateTeam(teamId: widget.team.id, name: name, tag: tag);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _teamManageErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit team'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('team-name-field'),
            controller: _nameController,
            enabled: !_submitting,
            autofocus: true,
            maxLength: 50,
            decoration: const InputDecoration(labelText: 'Team name'),
          ),
          TextField(
            key: const Key('team-tag-field'),
            controller: _tagController,
            enabled: !_submitting,
            maxLength: 5,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: 'Tag', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-team'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

class _InviteByUsernameDialog extends ConsumerStatefulWidget {
  const _InviteByUsernameDialog({required this.teamId});

  final String teamId;

  @override
  ConsumerState<_InviteByUsernameDialog> createState() =>
      _InviteByUsernameDialogState();
}

class _InviteByUsernameDialogState
    extends ConsumerState<_InviteByUsernameDialog> {
  final _usernameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.replaceFirst('@', '').isEmpty) {
      setState(() => _error = 'Enter a username.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(teamsRepoProvider)
          .inviteByUsername(teamId: widget.teamId, username: username);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _inviteErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite by username'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('team-invite-username'),
            controller: _usernameController,
            enabled: !_submitting,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitting ? null : _submit(),
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: '@player',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'They will receive an invitation in Notifications.',
            style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('team-invite-submit'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Sending…' : 'Send invite'),
        ),
      ],
    );
  }
}

String _inviteErrorMessage(Object error) {
  final value = error.toString();
  if (value.contains('invited_user_not_found')) {
    return 'No player has that username.';
  }
  if (value.contains('cannot_invite_self')) {
    return 'You cannot invite yourself.';
  }
  if (value.contains('already_team_member')) {
    return 'That player is already on this team.';
  }
  if (value.contains('not_team_captain')) {
    return 'Only the team captain can invite players.';
  }
  return 'Could not send the invitation. Try again.';
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
    required this.userId,
    required this.handle,
    required this.rank,
    required this.role,
    required this.canManage,
    required this.onPromote,
    required this.onRemove,
  });

  final String userId;
  final String handle;
  final Rank rank;
  final String role;
  final bool canManage;
  final VoidCallback onPromote;
  final VoidCallback onRemove;

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
          if (canManage)
            PopupMenuButton<_RosterAction>(
              key: Key('member-actions-$userId'),
              tooltip: 'Member actions',
              icon: const Icon(
                Icons.more_vert,
                color: LbColors.textDim,
                size: 18,
              ),
              onSelected: (action) {
                switch (action) {
                  case _RosterAction.promote:
                    onPromote();
                    break;
                  case _RosterAction.remove:
                    onRemove();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _RosterAction.promote,
                  child: Text('Make captain'),
                ),
                PopupMenuItem(
                  value: _RosterAction.remove,
                  child: Text('Remove member'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _RosterAction { promote, remove }

class _LeaveTeamCard extends StatelessWidget {
  const _LeaveTeamCard({required this.isCaptain, required this.onLeave});
  final bool isCaptain;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      onTap: isCaptain ? null : onLeave,
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
                  isCaptain
                      ? 'Transfer captaincy to another member before leaving.'
                      : 'Cannot leave while the team is in a locked or live tournament.',
                  style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
                ),
              ],
            ),
          ),
          Icon(
            isCaptain ? Icons.lock_outline_rounded : Icons.chevron_right,
            color: isCaptain ? LbColors.textDim : LbColors.danger,
            size: 20,
          ),
        ],
      ),
    );
  }
}

String _teamManageErrorMessage(Object error) {
  final value = error.toString();
  if (value.contains('team_active')) {
    return 'Roster changes are locked during an active tournament.';
  }
  if (value.contains('captain_must_transfer')) {
    return 'Transfer captaincy before leaving the team.';
  }
  if (value.contains('not_team_captain')) {
    return 'Only the current captain can do that.';
  }
  if (value.contains('target_member_not_found')) {
    return 'That player is no longer on this team.';
  }
  return 'Could not update the team. Try again.';
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
