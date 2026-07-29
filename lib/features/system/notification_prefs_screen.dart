import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';

/// Per-kind push and email toggles persisted in Supabase.
class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState
    extends ConsumerState<NotificationPrefsScreen> {
  Map<NotifKind, bool>? _push;
  Map<NotifKind, bool>? _email;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final preferences = ref.watch(notificationPreferencesProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Could not load notification preferences.'),
        ),
        data: (value) {
          _push ??= Map.of(value.push);
          _email ??= Map.of(value.email);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              SectionLabel('Time-sensitive'),
              const SizedBox(height: 8),
              _prefTile(
                NotifKind.matchReady,
                'Match ready',
                'Fires 5 minutes before your match starts.',
              ),
              const SizedBox(height: 6),
              _prefTile(
                NotifKind.startingSoon,
                'Starting soon',
                'Tournament locks or bracket generation events.',
              ),
              const SizedBox(height: 6),
              _prefTile(
                NotifKind.disputeOpened,
                'Dispute opened',
                'Someone raised a dispute on your submitted result. 15m to respond.',
              ),
              const SizedBox(height: 20),
              SectionLabel('Progress'),
              const SizedBox(height: 8),
              _prefTile(
                NotifKind.rankUp,
                'Rank up',
                'You climbed to a new tier — Champion, Legend, etc.',
              ),
              const SizedBox(height: 6),
              _prefTile(
                NotifKind.badgeEarned,
                'Badge earned',
                'Achievement badges from the spec §4.4 set.',
              ),
              const SizedBox(height: 6),
              _prefTile(
                NotifKind.resultVerified,
                'Result verified',
                'Moderator cleared your submitted score.',
              ),
              const SizedBox(height: 20),
              SectionLabel('Social & money'),
              const SizedBox(height: 8),
              _prefTile(
                NotifKind.teamInvite,
                'Team invite',
                'A team invited you to join their roster.',
              ),
              const SizedBox(height: 6),
              _prefTile(
                NotifKind.payoutReceived,
                'Payout received',
                'PayMongo disbursed a prize to your GCash / Maya / bank.',
              ),
              const SizedBox(height: 24),
              Text(
                'FCM push + email delivery. Toggling off silences the channel — you can still see history in the Notifications tab.',
                style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _prefTile(NotifKind kind, String title, String body) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LbType.cardTitleSm),
          const SizedBox(height: 2),
          Text(body, style: LbType.bodyXs.copyWith(color: LbColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              _channelToggle(
                icon: Icons.notifications_active_rounded,
                label: 'PUSH',
                value: _push![kind] ?? true,
                onChanged: (v) => _save(kind, push: v),
              ),
              const SizedBox(width: 8),
              _channelToggle(
                icon: Icons.mail_outline_rounded,
                label: 'EMAIL',
                value: _email![kind] ?? false,
                onChanged: (v) => _save(kind, email: v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(NotifKind kind, {bool? push, bool? email}) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    setState(() {
      if (push != null) _push![kind] = push;
      if (email != null) _email![kind] = email;
    });
    try {
      await ref
          .read(settingsRepoProvider)
          .saveNotificationPreferences(
            user.id,
            LbNotificationPreferences(
              push: Map.of(_push!),
              email: Map.of(_email!),
            ),
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that preference.')),
      );
    }
  }

  Widget _channelToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? LbColors.lime : LbColors.surfaceHi,
          border: Border.all(color: value ? LbColors.lime : LbColors.border),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: value ? LbColors.limeInk : LbColors.textDim,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: LbType.metaSm.copyWith(
                color: value ? LbColors.limeInk : LbColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
