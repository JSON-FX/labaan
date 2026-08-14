import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';

class AdminEconomyScreen extends ConsumerStatefulWidget {
  const AdminEconomyScreen({super.key});

  @override
  ConsumerState<AdminEconomyScreen> createState() => _AdminEconomyScreenState();
}

class _AdminEconomyScreenState extends ConsumerState<AdminEconomyScreen> {
  String _query = '';

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    LbEconomyRiskCase riskCase,
    bool dismissed,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dismissed ? 'Dismiss risk case' : 'Resolve risk case'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Resolution reason',
            hintText: 'At least 10 characters',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.length < 10 || !context.mounted) return;
    try {
      await ref
          .read(adminEconomyRepoProvider)
          .resolveRiskCase(
            caseId: riskCase.id,
            dismissed: dismissed,
            reason: reason,
          );
      ref.invalidate(adminEconomyDashboardProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this risk case.')),
        );
      }
    }
  }

  Future<void> _adjustWallet(BuildContext context, WidgetRef ref) async {
    final player = TextEditingController();
    final amount = TextEditingController();
    final reason = TextEditingController();
    var currency = LbWalletCurrency.entryCredit;
    var grant = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Audited wallet adjustment'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: player,
                  decoration: const InputDecoration(labelText: 'Player UUID'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                DropdownButtonFormField<LbWalletCurrency>(
                  initialValue: currency,
                  items: const [
                    DropdownMenuItem(
                      value: LbWalletCurrency.entryCredit,
                      child: Text('Credits'),
                    ),
                    DropdownMenuItem(
                      value: LbWalletCurrency.rewardPoint,
                      child: Text('Victory Points'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => currency = value ?? currency),
                ),
                SwitchListTile(
                  value: grant,
                  title: Text(grant ? 'Grant value' : 'Deduct value'),
                  onChanged: (value) => setDialogState(() => grant = value),
                ),
                TextField(
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Required support reason',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SUBMIT'),
            ),
          ],
        ),
      ),
    );
    final parsedAmount = int.tryParse(amount.text);
    if (confirmed == true &&
        parsedAmount != null &&
        parsedAmount > 0 &&
        reason.text.trim().length >= 10 &&
        context.mounted) {
      try {
        await ref
            .read(adminEconomyRepoProvider)
            .adjustWallet(
              targetUserId: player.text.trim(),
              currency: currency,
              grant: grant,
              amount: parsedAmount,
              reason: reason.text.trim(),
              idempotencyKey:
                  'admin-ui:${DateTime.now().microsecondsSinceEpoch}',
            );
        ref.invalidate(adminEconomyDashboardProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Adjustment recorded.')));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adjustment was not applied.')),
          );
        }
      }
    }
    player.dispose();
    amount.dispose();
    reason.dispose();
  }

  Future<void> _allocateRewardFunding(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final tournament = TextEditingController();
    final reference = TextEditingController();
    final attribution = TextEditingController();
    final amount = TextEditingController();
    final cap = TextEditingController();
    final reason = TextEditingController();
    var brandSponsored = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Allocate reward funding'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<bool>(
                    initialValue: brandSponsored,
                    decoration: const InputDecoration(labelText: 'Source'),
                    items: const [
                      DropdownMenuItem(
                        value: false,
                        child: Text('Platform promotion'),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text('Named brand sponsor'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => brandSponsored = value ?? false),
                  ),
                  TextField(
                    controller: tournament,
                    decoration: const InputDecoration(
                      labelText: 'Tournament UUID',
                    ),
                  ),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Unique campaign reference',
                    ),
                  ),
                  if (brandSponsored)
                    TextField(
                      controller: attribution,
                      decoration: const InputDecoration(
                        labelText: 'Public sponsor name',
                      ),
                    ),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Victory Point amount',
                    ),
                  ),
                  TextField(
                    controller: cap,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Campaign/source cap',
                    ),
                  ),
                  TextField(
                    controller: reason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Required audit reason',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ALLOCATE'),
            ),
          ],
        ),
      ),
    );
    final parsedAmount = int.tryParse(amount.text);
    final parsedCap = int.tryParse(cap.text);
    final valid =
        confirmed == true &&
        tournament.text.trim().isNotEmpty &&
        reference.text.trim().length >= 3 &&
        parsedAmount != null &&
        parsedAmount > 0 &&
        parsedCap != null &&
        parsedCap >= parsedAmount &&
        reason.text.trim().length >= 10 &&
        (!brandSponsored || attribution.text.trim().length >= 2);
    if (valid && context.mounted) {
      try {
        await ref
            .read(adminEconomyRepoProvider)
            .allocateRewardFunding(
              tournamentId: tournament.text.trim(),
              brandSponsored: brandSponsored,
              fundingReference: reference.text.trim(),
              attributionName: brandSponsored ? attribution.text.trim() : null,
              amount: parsedAmount!,
              sourceCap: parsedCap!,
              reason: reason.text.trim(),
            );
        ref.invalidate(adminEconomyDashboardProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reward funding allocated.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reward funding was not allocated.')),
          );
        }
      }
    }
    for (final controller in [
      tournament,
      reference,
      attribution,
      amount,
      cap,
      reason,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _runShopFulfillment(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Shop fulfillment'),
        content: const Text(
          'Claim up to 25 queued or retryable Shop items. Internal '
          'entitlements are delivered idempotently; unsupported or exhausted '
          'work moves to review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RUN'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final result = await ref
          .read(adminEconomyRepoProvider)
          .runShopFulfillment();
      ref.invalidate(adminEconomyDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Claimed ${result['claimed']} · fulfilled ${result['fulfilled']} '
              '· retrying ${result['retried']} · review ${result['review']}',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not run Shop fulfillment.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(adminEconomyDashboardProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: const Text('Economy operations'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(adminEconomyDashboardProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: kIsWeb
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'reward-funding',
                  onPressed: () => _allocateRewardFunding(context, ref),
                  label: const Text('FUND REWARDS'),
                  icon: const Icon(Icons.campaign_outlined),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'wallet-adjustment',
                  onPressed: () => _adjustWallet(context, ref),
                  label: const Text('ADJUST WALLET'),
                  icon: const Icon(Icons.tune),
                ),
              ],
            )
          : null,
      body: !kIsWeb
          ? const Center(child: Text('Admin operations are web-only.'))
          : dashboard.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Super-admin access is required.')),
              data: (data) => ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                children: [
                  const SectionLabel('Economy snapshot'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Metric(
                        'Outstanding CR',
                        data.summary['outstanding_credits'],
                      ),
                      _Metric(
                        'VP awarded',
                        data.summary['awarded_victory_points'],
                      ),
                      _Metric(
                        'VP redeemed',
                        data.summary['redeemed_victory_points'],
                      ),
                      _Metric(
                        'Pending cost PHP',
                        (data.summary['unfulfilled_expected_cost_centavos'] ??
                                0) /
                            100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Requires action'),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search order, tournament, or user ID',
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  LbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 20,
                          runSpacing: 12,
                          children: [
                            for (final entry in data.actionCounts.entries)
                              Text(
                                '${entry.key.toUpperCase()}  ${entry.value}',
                                style: LbType.bodySm,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _runShopFulfillment(context, ref),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('RUN SHOP FULFILLMENT'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in data.actionItems.where(_matchesQuery)) ...[
                    _ActionItemCard(item),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 22),
                  const SectionLabel('Risk review queue'),
                  const SizedBox(height: 8),
                  if (data.riskCases.isEmpty)
                    const LbCard(child: Text('No open risk cases.'))
                  else
                    for (final riskCase in data.riskCases) ...[
                      LbCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${riskCase.severity.toUpperCase()} · '
                              '${riskCase.signalType.replaceAll('_', ' ')}',
                              style: LbType.bodySm.copyWith(
                                color: LbColors.lime,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Occurrences: ${riskCase.occurrenceCount}'
                              '${riskCase.userId == null ? '' : ' · User ${riskCase.userId}'}',
                              style: LbType.bodySm,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _resolve(context, ref, riskCase, false),
                                  child: const Text('RESOLVE'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _resolve(context, ref, riskCase, true),
                                  child: const Text('DISMISS'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
    );
  }

  bool _matchesQuery(LbEconomyActionItem item) {
    if (_query.isEmpty) return true;
    return [
      item.category,
      item.id,
      item.state,
      item.status,
      item.userId,
      item.tournamentId,
    ].whereType<String>().any((value) => value.toLowerCase().contains(_query));
  }
}

class _ActionItemCard extends StatelessWidget {
  const _ActionItemCard(this.item);

  final LbEconomyActionItem item;

  @override
  Widget build(BuildContext context) => LbCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${item.category.toUpperCase()} · '
          '${item.state.replaceAll('_', ' ').toUpperCase()}',
          style: LbType.bodySm.copyWith(color: LbColors.lime),
        ),
        const SizedBox(height: 5),
        SelectableText(item.id, style: LbType.bodySm),
        const SizedBox(height: 5),
        Text(
          [
            item.status.replaceAll('_', ' '),
            if (item.amount != null) 'Amount ${item.amount}',
            if (item.userId != null) 'User ${item.userId}',
            if (item.tournamentId != null) 'Tournament ${item.tournamentId}',
          ].join(' · '),
          style: LbType.metaSm,
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final num? value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: LbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: LbType.metaSm),
          const SizedBox(height: 6),
          Text('${value ?? 0}', style: LbType.sectionTitle),
        ],
      ),
    ),
  );
}
