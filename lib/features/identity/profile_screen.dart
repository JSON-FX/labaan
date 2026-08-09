import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/badges.dart';
import '../../core/domain/ranks.dart';
import '../../core/domain/tournament_tier.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/lb_chip.dart';
import '../../core/widgets/rank_hex.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../../core/widgets/team_avatar.dart';

/// Identity · 1A · Player Profile.
///
/// Consumes [profileByIdProvider(currentUserId)]. All stats, badges, and
/// tournament history derive from the [LbPlayerProfile] composed view.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.pickAvatar});

  final Future<XFile?> Function()? pickAvatar;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar(LbUser user) async {
    if (_uploadingAvatar) return;
    final image =
        await (widget.pickAvatar?.call() ??
            ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1024,
              maxHeight: 1024,
              imageQuality: 88,
            ));
    if (image == null || !mounted) return;

    final extension = image.path.split('.').last.toLowerCase();
    var contentType = image.mimeType?.toLowerCase();
    contentType ??= switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    const supported = {'image/jpeg', 'image/png', 'image/webp'};
    if (!supported.contains(contentType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a JPG, PNG, or WebP image.')),
      );
      return;
    }

    final bytes = await image.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar must be 2 MB or smaller.')),
      );
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      await ref
          .read(profileRepoProvider)
          .uploadAvatar(
            userId: user.id,
            bytes: bytes,
            contentType: contentType!,
          );
      ref.invalidate(profileByIdProvider(user.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload your profile photo.')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const _Skeleton(),
      );
    }
    final async = ref.watch(profileByIdProvider(user.id));
    final teamsAsync = ref.watch(teamsForUserProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const _Skeleton(),
        error: (err, _) => _ErrorState(
          message: 'Could not load your profile',
          onRetry: () => ref.invalidate(profileByIdProvider(user.id)),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            _IdentityBlock(
              profile: p,
              avatar: _AvatarPicker(
                profile: p,
                uploading: _uploadingAvatar,
                onTap: () => _pickAndUploadAvatar(user),
              ),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Career'),
            const SizedBox(height: 8),
            _CareerStats(profile: p),
            const SizedBox(height: 20),
            SectionLabel(
              'Badges',
              trailing: Text(
                '${p.badges.length} OF ${AchievementBadge.values.length} EARNED',
                style: LbType.metaSm.copyWith(color: LbColors.textDim),
              ),
            ),
            const SizedBox(height: 10),
            _BadgeShelf(badges: p.badges),
            const SizedBox(height: 20),
            const SectionLabel('Teams'),
            const SizedBox(height: 8),
            teamsAsync.when(
              loading: () =>
                  const LbCard(child: LinearProgressIndicator(minHeight: 2)),
              error: (_, _) => _ErrorState(
                message: 'Could not load your teams',
                onRetry: () => ref.invalidate(teamsForUserProvider(user.id)),
              ),
              data: (teams) =>
                  _TeamsList(teams: teams, userId: user.id, rank: p.rank.rank),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Recent tournaments'),
            const SizedBox(height: 8),
            if (p.recentTournaments.isEmpty)
              _EmptyState(hint: 'No tournaments finished yet.')
            else
              for (final r in p.recentTournaments) ...[
                _RecentTournamentRow(entry: r),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _TeamsList extends StatelessWidget {
  const _TeamsList({
    required this.teams,
    required this.userId,
    required this.rank,
  });

  final List<LbTeam> teams;
  final String userId;
  final Rank rank;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const _EmptyState(
        hint: 'Not on any team yet. Search for players to invite.',
      );
    }
    return Column(
      children: [
        for (var index = 0; index < teams.length; index++) ...[
          _TeamRow(
            code: teams[index].tag,
            name: teams[index].name,
            role:
                '${teams[index].captainUserId == userId ? 'CAPTAIN' : 'MEMBER'}'
                ' · ${rank.displayName.toUpperCase()}',
          ),
          if (index < teams.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.profile, required this.avatar});
  final LbPlayerProfile profile;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final rank = profile.rank.rank;
    final wins = profile.rank.totalWins;
    final winsToNext = rank.winsToNext(wins);
    final progress = rank.progressWithin(wins);
    final next = rank.next ?? rank;
    return LbCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    Text(
                      rank.displayName.toUpperCase(),
                      style: LbType.metaSm.copyWith(
                        color: rankAccent(rank),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    LbChip(
                      profile.gamesPlayed.join(' · '),
                      tone: LbChipTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  profile.user.username,
                  style: LbType.sectionTitle.copyWith(letterSpacing: -0.2),
                ),
                Text(
                  '${profile.user.region ?? "PH"} · ${profile.user.email}',
                  style: LbType.metaSm.copyWith(color: LbColors.textDim),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: LbColors.borderMuted,
                  valueColor: const AlwaysStoppedAnimation(LbColors.lime),
                ),
                const SizedBox(height: 4),
                Text(
                  '$winsToNext WINS TO ${next.displayName.toUpperCase()} · RANK ${next.level}',
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

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.profile,
    required this.uploading,
    required this.onTap,
  });

  final LbPlayerProfile profile;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.user.avatarUrl;
    final fallback = RankHex(
      rank: profile.rank.rank.level,
      size: 76,
      color: rankAccent(profile.rank.rank),
    );
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: Tooltip(
        message: 'Change profile photo',
        child: InkWell(
          key: const Key('profile-avatar-picker'),
          onTap: uploading ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 82,
            height: 82,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (avatarUrl == null || avatarUrl.isEmpty)
                  fallback
                else
                  ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: LbColors.lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: LbColors.surface, width: 2),
                    ),
                    child: uploading
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: LbColors.limeInk,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: LbColors.limeInk,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareerStats extends StatelessWidget {
  const _CareerStats({required this.profile});
  final LbPlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final wr = (profile.winRate * 100).toStringAsFixed(0);
    return Row(
      children: [
        Expanded(
          child: _StatTile(label: 'MATCHES', value: '${profile.totalMatches}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(label: 'WIN %', value: '$wr%'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'VICTORY PTS',
            value: '${profile.totalRewardPoints} VP',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: LbType.metaSm.copyWith(fontSize: 9, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
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

class _BadgeShelf extends StatelessWidget {
  const _BadgeShelf({required this.badges});
  final List<AchievementBadge> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return _EmptyState(
        hint: 'No badges yet. Win a tournament to earn First Blood.',
      );
    }
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final b = badges[i];
          return SizedBox(
            width: 68,
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [b.color.withValues(alpha: 0.4), b.color],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(b.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 5),
                Text(
                  b.displayName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textSecondary,
                    fontSize: 8.5,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.code, required this.name, required this.role});
  final String code;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          TeamAvatar(code: code, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: LbType.cardTitleSm),
                Text(
                  role,
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: LbColors.textDim, size: 20),
        ],
      ),
    );
  }
}

class _RecentTournamentRow extends StatelessWidget {
  const _RecentTournamentRow({required this.entry});
  final LbCompletedTournament entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.wasWin;
    return LbCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          RankHex(
            rank: entry.finalPlace,
            size: 34,
            color: positive ? LbColors.lime : LbColors.textDim,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.tournament.title, style: LbType.cardTitleSm),
                Text(
                  '${entry.tournament.game} · ${positive ? "1ST" : "OUT"}',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.tournament.usesWallet
                ? '${entry.rewardPoints} VP'
                : formatPeso(entry.payoutPhp, decimals: 0),
            style: LbType.rankNumeral(15, color: LbColors.lime),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      children: [block(120), block(72), block(76), block(60), block(60)],
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
