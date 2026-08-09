import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';

typedef ExternalLauncher = Future<bool> Function(Uri uri);

class HostTournamentScreen extends StatelessWidget {
  const HostTournamentScreen({super.key, this.externalLauncher});

  final ExternalLauncher? externalLauncher;

  Future<void> _openGabRegistry(BuildContext context) async {
    final uri = Uri.parse('https://gab.gov.ph/');
    try {
      final opened =
          await (externalLauncher?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the GAB permit registry.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Host a tournament'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          LbCard(
            highlighted: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORGANIZER PORTAL',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.lime,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Host on Labaan', style: LbType.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  'Tournament creation and operations live in Labaan’s '
                  'separate organizer application. The player app never '
                  'grants organizer access or creates tournaments directly.',
                  style: LbType.bodySm.copyWith(color: LbColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Organizer onboarding'),
          const SizedBox(height: 8),
          const _HostStep(
            number: '01',
            title: 'Identity & role review',
            body:
                'Organizer access is provisioned separately from a player account.',
          ),
          const SizedBox(height: 8),
          const _HostStep(
            number: '02',
            title: 'Tournament compliance',
            body:
                'Prepare required rules, payout details, and GAB permit information.',
          ),
          const SizedBox(height: 8),
          const _HostStep(
            number: '03',
            title: 'Operate from the dashboard',
            body:
                'Create brackets, assign moderators, and resolve queues outside the player app.',
          ),
          const SizedBox(height: 20),
          SlantButton(
            label: 'Organizer support',
            onPressed: () => context.push('/support?topic=organizer'),
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'GAB registry',
            onPressed: () => _openGabRegistry(context),
          ),
        ],
      ),
    );
  }
}

class _HostStep extends StatelessWidget {
  const _HostStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: LbType.rankNumeral(18, color: LbColors.lime)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LbType.cardTitleSm),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
