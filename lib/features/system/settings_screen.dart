import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/providers.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';

/// Reachable from Profile app-bar cog. Groups: Account, Notifications,
/// Connected accounts, Legal, Danger zone. Delete-account is deliberately a
/// full destructive confirmation flow.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    final linkedProviders =
        ref.watch(linkedProvidersProvider).value ?? const {};
    final payout = ref.watch(payoutAccountProvider(user.id)).value;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          SectionLabel('Account'),
          const SizedBox(height: 8),
          _SettingsRow(
            icon: Icons.person_rounded,
            label: 'Username',
            value: user.username,
            onTap: () => context.push('/settings/username'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.mail_rounded,
            label: 'Email',
            value: user.email.isEmpty ? 'Not set' : user.email,
            onTap: () => context.push('/settings/email'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.pin_drop_rounded,
            label: 'Region',
            value: user.region ?? 'Not set',
            onTap: () => context.push('/settings/region'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.sports_esports_rounded,
            label: 'Games',
            value: user.games.isEmpty ? 'None' : user.games.join(' · '),
            onTap: () => context.push('/settings/games'),
          ),
          const SizedBox(height: 20),
          SectionLabel('Notifications'),
          const SizedBox(height: 8),
          _SettingsRow(
            icon: Icons.notifications_rounded,
            label: 'Push preferences',
            value: 'Per-kind toggles',
            onTap: () => context.push('/settings/notifications'),
          ),
          const SizedBox(height: 20),
          SectionLabel('Connected accounts'),
          const SizedBox(height: 8),
          _SettingsRow(
            icon: Icons.g_mobiledata_rounded,
            label: 'Google',
            value: linkedProviders.contains('google.com')
                ? 'Connected'
                : 'Not connected',
            valueColor: linkedProviders.contains('google.com')
                ? LbColors.lime
                : null,
            onTap: () => context.push('/settings/accounts'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.facebook_rounded,
            label: 'Facebook',
            value: 'Unavailable',
            onTap: () => context.push('/settings/accounts'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: user.phone ?? 'Not linked',
            onTap: () => context.push('/settings/accounts'),
          ),
          const SizedBox(height: 20),
          SectionLabel('Payouts'),
          const SizedBox(height: 8),
          _SettingsRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Payout account',
            value: payout == null
                ? 'Not set'
                : '${payout.provider.toUpperCase()} · ${payout.maskedNumber}',
            onTap: () => context.push('/settings/payout'),
          ),
          const SizedBox(height: 20),
          SectionLabel('Legal'),
          const SizedBox(height: 8),
          _SettingsRow(
            icon: Icons.privacy_tip_rounded,
            label: 'Privacy policy',
            onTap: () => context.push('/settings/privacy'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.description_rounded,
            label: 'Terms of service',
            onTap: () => context.push('/settings/terms'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.emoji_events_rounded,
            label: 'Tournament rules',
            onTap: () => context.push('/settings/tournament-rules'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.campaign_rounded,
            label: 'Organizer sponsorship terms',
            onTap: () => context.push('/settings/sponsorship-terms'),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.verified_rounded,
            label: 'GAB permit registry',
            onTap: () => launchUrl(
              Uri.parse('https://gab.gov.ph/'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 24),
          SlantButton(
            label: 'Sign out',
            onPressed: () async {
              await PushNotificationService.instance.unregisterCurrentToken();
              await ref.read(authRepoProvider).signOut();
              if (!context.mounted) return;
              context.go('/onboarding');
            },
            color: LbColors.surfaceHi,
            foreground: LbColors.textPrimary,
            glow: false,
          ),
          const SizedBox(height: 20),
          SectionLabel('Danger zone'),
          const SizedBox(height: 8),
          LbCard(
            padding: const EdgeInsets.all(12),
            onTap: () => context.push('/settings/delete-account'),
            child: Row(
              children: [
                const Icon(
                  Icons.delete_forever_rounded,
                  color: LbColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete account',
                        style: LbType.cardTitleSm.copyWith(
                          color: LbColors.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Request permanent account closure and data review.',
                        style: LbType.bodyXs.copyWith(
                          color: LbColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Labaan · v1.0.0 · MVP',
              style: LbType.metaSm.copyWith(
                color: LbColors.textDim,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: LbColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: LbType.cardTitleSm)),
          if (value != null) ...[
            Text(
              value!,
              style: LbType.metaSm.copyWith(
                color: valueColor ?? LbColors.textMuted,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right, color: LbColors.textDim, size: 18),
        ],
      ),
    );
  }
}
