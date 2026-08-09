import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, this.topic});

  final String? topic;

  @override
  Widget build(BuildContext context) {
    final organizerHelp = topic == 'organizer';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Help & support'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          if (organizerHelp) ...[
            LbCard(
              highlighted: true,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: LbColors.lime,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Organizer access', style: LbType.cardTitleSm),
                        const SizedBox(height: 3),
                        Text(
                          'Organizer onboarding and tournament operations are '
                          'handled in the separate web application. They are '
                          'not available as player-account permissions here.',
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
            const SizedBox(height: 20),
          ],
          const SectionLabel('Account & preferences'),
          const SizedBox(height: 8),
          _SupportDestination(
            icon: Icons.link_rounded,
            title: 'Connected accounts',
            detail: 'Google and phone sign-in methods',
            onTap: () => context.push('/settings/accounts'),
          ),
          const SizedBox(height: 8),
          _SupportDestination(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Payout support',
            detail: 'Review your GCash or Maya destination',
            onTap: () => context.push('/settings/payout'),
          ),
          const SizedBox(height: 8),
          _SupportDestination(
            icon: Icons.notifications_rounded,
            title: 'Notification settings',
            detail: 'Control tournament and account alerts',
            onTap: () => context.push('/settings/notifications'),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Competition & safety'),
          const SizedBox(height: 8),
          _SupportDestination(
            icon: Icons.sports_esports_rounded,
            title: 'Competition issues',
            detail: 'Open your tournament to submit or dispute a result',
            onTap: () => context.go('/compete'),
          ),
          const SizedBox(height: 8),
          _SupportDestination(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy & account data',
            detail: 'Review the privacy policy and deletion process',
            onTap: () => context.push('/settings/privacy'),
          ),
          const SizedBox(height: 8),
          _SupportDestination(
            icon: Icons.description_rounded,
            title: 'Terms of service',
            detail: 'Platform rules and player responsibilities',
            onTap: () => context.push('/settings/terms'),
          ),
          const SizedBox(height: 20),
          LbCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Direct case submission will be connected when the separate '
              'organizer/support application is provisioned. These self-service '
              'destinations use the live settings and competition flows today.',
              style: LbType.bodyXs.copyWith(color: LbColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportDestination extends StatelessWidget {
  const _SupportDestination({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: LbColors.lime, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LbType.cardTitleSm),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: LbColors.textDim, size: 18),
        ],
      ),
    );
  }
}
