import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/slant_button.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _confirmation = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _request(String userId) async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepoProvider).requestAccountDeletion();
      ref.invalidate(accountDeletionRequestProvider(userId));
      _confirmation.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not schedule account deletion.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(String userId) async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepoProvider).cancelAccountDeletion();
      ref.invalidate(accountDeletionRequestProvider(userId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel account deletion.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final request = ref.watch(accountDeletionRequestProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: const Text('Delete account'),
      ),
      body: request.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Could not load account-deletion status.'),
        ),
        data: (value) => value != null && value.canCancel
            ? _ScheduledDeletion(
                request: value,
                busy: _busy,
                onCancel: () => _cancel(user.id),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: LbColors.danger,
                    size: 44,
                  ),
                  const SizedBox(height: 14),
                  Text('Permanent account closure', style: LbType.screenTitle),
                  const SizedBox(height: 10),
                  Text(
                    'Your request has a 30-day cancellation period. After that, your Firebase sign-in and direct profile identifiers are permanently deleted.',
                    style: LbType.bodySm,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Payment, payout, tournament, dispute, and audit records may remain pseudonymized for up to five years for financial integrity, legal claims, and compliance. Team captains must transfer ownership, and unsettled payouts require review before cleanup.',
                    style: LbType.bodySm,
                  ),
                  const SizedBox(height: 18),
                  const LbCard(
                    child: Text(
                      'This cannot be undone after processing. You will not be able to recreate a Labaan account with the same Firebase identity during the retention period.',
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _confirmation,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Type DELETE to confirm',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SlantButton(
                    label: _busy ? 'Scheduling…' : 'Schedule account deletion',
                    color: LbColors.danger,
                    foreground: Colors.white,
                    glow: false,
                    onPressed: !_busy && _confirmation.text == 'DELETE'
                        ? () => _request(user.id)
                        : null,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ScheduledDeletion extends StatelessWidget {
  const _ScheduledDeletion({
    required this.request,
    required this.busy,
    required this.onCancel,
  });

  final LbAccountDeletionRequest request;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final date = request.scheduledFor.toLocal();
    final review = request.status == LbAccountDeletionStatus.underReview;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Icon(
          review ? Icons.policy_rounded : Icons.schedule_rounded,
          color: review ? LbColors.gold : LbColors.danger,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          review ? 'Deletion requires review' : 'Deletion scheduled',
          textAlign: TextAlign.center,
          style: LbType.screenTitle,
        ),
        const SizedBox(height: 10),
        Text(
          review
              ? 'Cleanup is paused until team ownership or payout obligations are resolved.'
              : 'Permanent cleanup is scheduled for ${_date(date)}.',
          textAlign: TextAlign.center,
          style: LbType.bodySm,
        ),
        const SizedBox(height: 22),
        SlantButton(
          label: busy ? 'Cancelling…' : 'Cancel deletion request',
          onPressed: busy ? null : onCancel,
          color: LbColors.surfaceHi,
          foreground: LbColors.textPrimary,
          glow: false,
        ),
      ],
    );
  }
}

String _date(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
