import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/slant_button.dart';

class PayoutAccountScreen extends ConsumerStatefulWidget {
  const PayoutAccountScreen({super.key});

  @override
  ConsumerState<PayoutAccountScreen> createState() =>
      _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends ConsumerState<PayoutAccountScreen> {
  final _name = TextEditingController();
  final _number = TextEditingController(text: '+63');
  String _provider = 'gcash';
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _initialize(LbPayoutAccount? account) {
    if (_initialized) return;
    _initialized = true;
    if (account == null) return;
    _provider = account.provider;
    _name.text = account.accountName;
    _number.text = account.mobileNumber;
  }

  Future<void> _save(String userId) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsRepoProvider)
          .savePayoutAccount(
            userId,
            LbPayoutAccount(
              provider: _provider,
              accountName: _name.text.trim(),
              mobileNumber: _number.text.replaceAll(RegExp(r'\s+'), ''),
            ),
          );
      ref.invalidate(payoutAccountProvider(userId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payout account saved.')));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the payout account.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(String userId) async {
    await ref.read(settingsRepoProvider).deletePayoutAccount(userId);
    ref.invalidate(payoutAccountProvider(userId));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final account = ref.watch(payoutAccountProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: const Text('Payout account'),
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Could not load your payout account.')),
        data: (value) {
          _initialize(value);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              Text(
                'Prize payouts will be sent to this verified-name mobile wallet.',
                style: LbType.bodySm,
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'gcash', label: Text('GCash')),
                  ButtonSegment(value: 'maya', label: Text('Maya')),
                ],
                selected: {_provider},
                onSelectionChanged: (selection) =>
                    setState(() => _provider = selection.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _number,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '+639171234567',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Use the name registered with your wallet. Your full number is protected by account-level database access rules.',
                style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
              ),
              const SizedBox(height: 24),
              SlantButton(
                label: _saving ? 'Saving…' : 'Save payout account',
                onPressed: _valid && !_saving ? () => _save(user.id) : null,
              ),
              if (value != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _saving ? null : () => _remove(user.id),
                  style: TextButton.styleFrom(foregroundColor: LbColors.danger),
                  child: const Text('REMOVE PAYOUT ACCOUNT'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  bool get _valid =>
      _name.text.trim().length >= 2 &&
      RegExp(
        r'^\+639\d{9}$',
      ).hasMatch(_number.text.replaceAll(RegExp(r'\s+'), ''));
}
