import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/data/repos.dart';
import '../../core/domain/tournament_tier.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';

typedef ExternalLauncher = Future<bool> Function(Uri uri);

class HostTournamentScreen extends ConsumerStatefulWidget {
  const HostTournamentScreen({super.key, this.externalLauncher});

  final ExternalLauncher? externalLauncher;

  @override
  ConsumerState<HostTournamentScreen> createState() =>
      _HostTournamentScreenState();
}

class _HostTournamentScreenState extends ConsumerState<HostTournamentScreen> {
  String? _tournamentId;
  String? _packageId;
  PayMethod _method = PayMethod.gcash;
  bool _showAttribution = true;
  bool _submitting = false;
  String? _idempotencyKey;

  Future<void> _createTournamentDraft() async {
    final title = TextEditingController();
    final game = TextEditingController(text: 'MLBB');
    final entryCost = TextEditingController(text: '100');
    final maxTeams = TextEditingController(text: '8');
    final minimumTeams = TextEditingController(text: '4');
    final rewardRate = TextEditingController(text: '100');
    final rewardCap = TextEditingController(text: '800');
    var format = 'single_elimination';
    var underfill = 'cancel';
    final draft = await showDialog<LbWalletTournamentDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Wallet tournament'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: game,
                    decoration: const InputDecoration(labelText: 'Game'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: format,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: const [
                      DropdownMenuItem(
                        value: 'single_elimination',
                        child: Text('Single elimination'),
                      ),
                      DropdownMenuItem(
                        value: 'double_elimination',
                        child: Text('Double elimination'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => format = value ?? format),
                  ),
                  _NumberField(controller: entryCost, label: 'Entry Credits'),
                  _NumberField(controller: maxTeams, label: 'Maximum teams'),
                  _NumberField(
                    controller: minimumTeams,
                    label: 'Minimum teams',
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: underfill,
                    decoration: const InputDecoration(
                      labelText: 'Below minimum',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cancel', child: Text('Cancel')),
                      DropdownMenuItem(
                        value: 'postpone',
                        child: Text('Postpone'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => underfill = value ?? underfill),
                  ),
                  _NumberField(
                    controller: rewardRate,
                    label: 'Victory Points per confirmed team',
                  ),
                  _NumberField(
                    controller: rewardCap,
                    label: 'Victory Point pool cap',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Placement split: 70% first · 30% second. The complete '
                    'formula is locked before registration opens.',
                    style: LbType.metaSm,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final values = [
                  int.tryParse(entryCost.text),
                  int.tryParse(maxTeams.text),
                  int.tryParse(minimumTeams.text),
                  int.tryParse(rewardRate.text),
                  int.tryParse(rewardCap.text),
                ];
                if (title.text.trim().length < 4 ||
                    game.text.trim().length < 2 ||
                    values.any((value) => value == null || value <= 0)) {
                  return;
                }
                Navigator.pop(
                  context,
                  LbWalletTournamentDraft(
                    title: title.text.trim(),
                    game: game.text.trim(),
                    format: format,
                    entryCreditCost: values[0]!,
                    maxTeams: values[1]!,
                    minimumTeams: values[2]!,
                    belowMinimumAction: underfill,
                    rewardPointsPerCompetitor: values[3]!,
                    rewardPoolCap: values[4]!,
                  ),
                );
              },
              child: const Text('CREATE DRAFT'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      title,
      game,
      entryCost,
      maxTeams,
      minimumTeams,
      rewardRate,
      rewardCap,
    ]) {
      controller.dispose();
    }
    if (draft == null || !mounted) return;
    try {
      await ref.read(hostSponsorRepoProvider).createTournamentDraft(draft);
      ref.invalidate(hostSponsorPortalProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet tournament draft created.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create the tournament draft.'),
          ),
        );
      }
    }
  }

  Future<void> _openGabRegistry(BuildContext context) async {
    final uri = Uri.parse('https://gab.gov.ph/');
    try {
      final opened =
          await (widget.externalLauncher?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the GAB permit registry.')),
    );
  }

  void _changeSelection(VoidCallback change) {
    setState(() {
      change();
      _idempotencyKey = null;
    });
  }

  Future<void> _startCheckout(
    LbTournament tournament,
    LbSponsorPackage package,
  ) async {
    setState(() => _submitting = true);
    _idempotencyKey ??=
        'sponsor:${tournament.id}:${package.id}:${DateTime.now().microsecondsSinceEpoch}';
    final success = Uri.base.resolve('/host?sponsorResult=pending');
    final cancel = Uri.base.resolve('/host?sponsorResult=cancelled');
    try {
      final checkout = await ref
          .read(hostSponsorRepoProvider)
          .createCheckout(
            tournamentId: tournament.id,
            package: package,
            method: _method,
            showAttribution: _showAttribution,
            idempotencyKey: _idempotencyKey!,
            successUrl: success,
            cancelUrl: cancel,
          );
      final opened = await launchUrl(
        checkout.checkoutUrl,
        webOnlyWindowName: '_self',
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PayMongo Checkout.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start sponsorship checkout.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _publishTournament(LbTournament tournament) async {
    final lockTime = await _pickDateTime(
      DateTime.now().add(const Duration(days: 6)),
    );
    if (lockTime == null || !mounted) return;
    final startTime = await _pickDateTime(
      lockTime.add(const Duration(hours: 1)),
    );
    if (startTime == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish tournament?'),
        content: Text(
          'Registration locks ${lockTime.toLocal()}\n'
          'Tournament starts ${startTime.toLocal()}\n\n'
          'Publishing opens Credit registration and locks the published '
          'reward rules after the first confirmed entry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('PUBLISH'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(hostSponsorRepoProvider)
          .publishTournament(
            tournamentId: tournament.id,
            registrationLocksAt: lockTime,
            startsAt: startTime,
          );
      ref.invalidate(hostSponsorPortalProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament registration is open.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not publish this tournament.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(economyFeaturesProvider).asData?.value;
    final sponsorshipEnabled =
        features?.isEnabled(LbEconomyFeature.organizerSponsorship) ?? false;
    final session = ref.watch(currentUserProvider);
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
                  kIsWeb
                      ? 'Fund a fixed Victory Point boost for an eligible '
                            'draft tournament. PayMongo checkout and signed '
                            'webhooks keep pricing and rewards server-owned.'
                      : 'Tournament sponsorship and operations live in '
                            'Labaan’s web organizer portal. The player app '
                            'never grants organizer access directly.',
                  style: LbType.bodySm.copyWith(color: LbColors.textMuted),
                ),
              ],
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            SlantButton(
              label: 'Create Wallet tournament',
              onPressed: _createTournamentDraft,
            ),
            const SizedBox(height: 8),
            GhostButton(
              label: 'Sponsorship terms',
              onPressed: () => context.push('/settings/sponsorship-terms'),
            ),
          ],
          if (kIsWeb && sponsorshipEnabled) ...[
            const SizedBox(height: 20),
            session.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const _PortalMessage(
                message: 'Could not load your organizer session.',
              ),
              data: (user) => user == null
                  ? const _PortalMessage(
                      message: 'Sign in to access organizer sponsorship.',
                    )
                  : _SponsorPortal(
                      portal: ref.watch(hostSponsorPortalProvider(user.id)),
                      tournamentId: _tournamentId,
                      packageId: _packageId,
                      method: _method,
                      showAttribution: _showAttribution,
                      submitting: _submitting,
                      onTournamentChanged: (value) =>
                          _changeSelection(() => _tournamentId = value),
                      onPackageChanged: (value) =>
                          _changeSelection(() => _packageId = value),
                      onMethodChanged: (value) =>
                          _changeSelection(() => _method = value),
                      onAttributionChanged: (value) =>
                          _changeSelection(() => _showAttribution = value),
                      onSubmit: _startCheckout,
                      onPublish: _publishTournament,
                    ),
            ),
          ],
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

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
  );
}

class _SponsorPortal extends StatelessWidget {
  const _SponsorPortal({
    required this.portal,
    required this.tournamentId,
    required this.packageId,
    required this.method,
    required this.showAttribution,
    required this.submitting,
    required this.onTournamentChanged,
    required this.onPackageChanged,
    required this.onMethodChanged,
    required this.onAttributionChanged,
    required this.onSubmit,
    required this.onPublish,
  });

  final AsyncValue<LbHostSponsorPortal> portal;
  final String? tournamentId;
  final String? packageId;
  final PayMethod method;
  final bool showAttribution;
  final bool submitting;
  final ValueChanged<String> onTournamentChanged;
  final ValueChanged<String> onPackageChanged;
  final ValueChanged<PayMethod> onMethodChanged;
  final ValueChanged<bool> onAttributionChanged;
  final Future<void> Function(LbTournament, LbSponsorPackage) onSubmit;
  final Future<void> Function(LbTournament) onPublish;

  @override
  Widget build(BuildContext context) => portal.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, _) =>
        const _PortalMessage(message: 'Could not load sponsorship options.'),
    data: (data) {
      if (data.tournaments.isEmpty) {
        return const _PortalMessage(
          message:
              'No eligible draft Wallet tournaments were found. Create one before adding a sponsor boost.',
        );
      }
      if (data.packages.isEmpty) {
        return const _PortalMessage(
          message: 'Sponsor packages are not available right now.',
        );
      }
      final selectedTournament = data.tournaments.firstWhere(
        (item) => item.id == tournamentId,
        orElse: () => data.tournaments.first,
      );
      final selectedPackage = data.packages.firstWhere(
        (item) => item.id == packageId,
        orElse: () => data.packages.first,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Sponsor a reward pool'),
          const SizedBox(height: 8),
          LbCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedTournament.id,
                  decoration: const InputDecoration(labelText: 'Tournament'),
                  items: [
                    for (final tournament in data.tournaments)
                      DropdownMenuItem(
                        value: tournament.id,
                        child: Text(tournament.title),
                      ),
                  ],
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value != null) onTournamentChanged(value);
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPackage.id,
                  decoration: const InputDecoration(labelText: 'Reward boost'),
                  items: [
                    for (final package in data.packages)
                      DropdownMenuItem(
                        value: package.id,
                        child: Text(
                          '${package.displayName} · ${package.rewardPointAmount} VP · '
                          '${formatPeso(package.pricePhp)}',
                        ),
                      ),
                  ],
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value != null) onPackageChanged(value);
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PayMethod>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Pay with'),
                  items: const [
                    DropdownMenuItem(
                      value: PayMethod.gcash,
                      child: Text('GCash'),
                    ),
                    DropdownMenuItem(
                      value: PayMethod.maya,
                      child: Text('Maya'),
                    ),
                    DropdownMenuItem(
                      value: PayMethod.qrph,
                      child: Text('QR Ph'),
                    ),
                    DropdownMenuItem(
                      value: PayMethod.card,
                      child: Text('Card'),
                    ),
                  ],
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value != null) onMethodChanged(value);
                        },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: showAttribution,
                  onChanged: submitting ? null : onAttributionChanged,
                  title: const Text('Show organizer attribution'),
                  subtitle: const Text(
                    'Your public username appears beside this reward boost.',
                  ),
                ),
                const SizedBox(height: 8),
                SlantButton(
                  label: submitting
                      ? 'Opening checkout…'
                      : 'Pay ${formatPeso(selectedPackage.pricePhp)}',
                  onPressed: submitting
                      ? null
                      : () => onSubmit(selectedTournament, selectedPackage),
                ),
                const SizedBox(height: 8),
                GhostButton(
                  label: 'Publish & open registration',
                  onPressed: submitting
                      ? null
                      : () => onPublish(selectedTournament),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add any sponsor boosts before publishing. Publishing ends '
                  'draft sponsorship and opens Credit registration.',
                  style: LbType.metaSm.copyWith(color: LbColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _PortalMessage extends StatelessWidget {
  const _PortalMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => LbCard(
    child: Text(
      message,
      style: LbType.bodySm.copyWith(color: LbColors.textMuted),
    ),
  );
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
