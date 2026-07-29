import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/slant_button.dart';

class ConnectedAccountsScreen extends ConsumerStatefulWidget {
  const ConnectedAccountsScreen({super.key});

  @override
  ConsumerState<ConnectedAccountsScreen> createState() =>
      _ConnectedAccountsScreenState();
}

class _ConnectedAccountsScreenState
    extends ConsumerState<ConnectedAccountsScreen> {
  final _phone = TextEditingController(text: '+63');
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _linkGoogle() => _run(() async {
    await ref.read(authRepoProvider).linkGoogle();
    ref.invalidate(linkedProvidersProvider);
    _message('Google account connected.');
  });

  Future<void> _phoneAction() => _run(() async {
    if (!_codeSent) {
      await ref
          .read(authRepoProvider)
          .requestPhoneLink(_phone.text.replaceAll(RegExp(r'\s+'), ''));
      if (!mounted) return;
      setState(() => _codeSent = true);
      _message('Verification code sent.');
      return;
    }
    await ref
        .read(authRepoProvider)
        .verifyPhoneLink(
          phoneE164: _phone.text.replaceAll(RegExp(r'\s+'), ''),
          token: _code.text.trim(),
        );
    ref.invalidate(linkedProvidersProvider);
    ref.invalidate(currentUserProvider);
    _message('Phone number connected.');
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      _message('Could not connect that account. It may already be in use.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(linkedProvidersProvider);
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: const Text('Connected accounts'),
      ),
      body: providers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load accounts.')),
        data: (items) {
          final googleLinked = items.contains('google.com');
          final phoneLinked = items.contains('phone');
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              _ProviderCard(
                icon: Icons.g_mobiledata_rounded,
                title: 'Google',
                subtitle: googleLinked
                    ? 'Connected'
                    : 'Use Google as another way to sign in.',
                connected: googleLinked,
                action: googleLinked || _busy ? null : _linkGoogle,
              ),
              const SizedBox(height: 8),
              _ProviderCard(
                icon: Icons.phone_rounded,
                title: 'Phone',
                subtitle: phoneLinked
                    ? (user?.phone ?? 'Connected')
                    : 'Add a verified Philippine mobile number.',
                connected: phoneLinked,
              ),
              if (!phoneLinked) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _codeSent ? _code : _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  maxLength: _codeSent ? 6 : null,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _codeSent ? 'Verification code' : 'Phone number',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                SlantButton(
                  label: _busy
                      ? 'Please wait…'
                      : (_codeSent ? 'Verify phone' : 'Send code'),
                  onPressed: _phoneValid && !_busy ? _phoneAction : null,
                ),
              ],
              const SizedBox(height: 8),
              const _ProviderCard(
                icon: Icons.facebook_rounded,
                title: 'Facebook',
                subtitle:
                    'Unavailable until the Facebook provider is configured.',
                connected: false,
              ),
              const SizedBox(height: 18),
              Text(
                'At least one sign-in method must remain connected. Disconnecting providers will be added with account recovery safeguards.',
                style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
              ),
            ],
          );
        },
      ),
    );
  }

  bool get _phoneValid => _codeSent
      ? RegExp(r'^\d{6}$').hasMatch(_code.text.trim())
      : RegExp(
          r'^\+63\d{10}$',
        ).hasMatch(_phone.text.replaceAll(RegExp(r'\s+'), ''));
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connected,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool connected;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: LbColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LbType.cardTitleSm),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
                ),
              ],
            ),
          ),
          if (connected)
            Text(
              'CONNECTED',
              style: LbType.metaSm.copyWith(color: LbColors.lime),
            )
          else if (action != null)
            TextButton(onPressed: action, child: const Text('CONNECT')),
        ],
      ),
    );
  }
}
