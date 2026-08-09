import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/tournament_tier.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';

enum _WalletFilter { all, entryFees, prizes }

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _WalletFilter _filter = _WalletFilter.all;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: const Text('Wallet'),
      ),
      body: RefreshIndicator(
        color: LbColors.lime,
        backgroundColor: LbColors.surface,
        onRefresh: () async {
          ref.invalidate(walletProvider);
          await ref.read(walletProvider.future);
        },
        child: wallet.when(
          loading: () => ListView(
            children: const [
              SizedBox(height: 300),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (_, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 180),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: LbColors.textDim,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load wallet activity.',
                textAlign: TextAlign.center,
                style: LbType.bodySm,
              ),
              TextButton(
                onPressed: () => ref.invalidate(walletProvider),
                child: const Text('TRY AGAIN'),
              ),
            ],
          ),
          data: (data) => _WalletBody(
            wallet: data,
            filter: _filter,
            onFilter: (value) => setState(() => _filter = value),
          ),
        ),
      ),
    );
  }
}

class _WalletBody extends StatelessWidget {
  const _WalletBody({
    required this.wallet,
    required this.filter,
    required this.onFilter,
  });

  final LbWallet wallet;
  final _WalletFilter filter;
  final ValueChanged<_WalletFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final visible = wallet.transactions.where((transaction) {
      return switch (filter) {
        _WalletFilter.all => true,
        _WalletFilter.entryFees =>
          transaction.kind == LbWalletTransactionKind.entryFee ||
              transaction.kind == LbWalletTransactionKind.refund,
        _WalletFilter.prizes =>
          transaction.kind == LbWalletTransactionKind.prize,
      };
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        _CashFlowCard(wallet: wallet),
        const SizedBox(height: 12),
        Text(
          'Activity reflects tournament charges and external payouts. It is not a stored balance.',
          style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
        ),
        const SizedBox(height: 16),
        SlantButton(
          label: 'Payout destination',
          leading: const Icon(Icons.account_balance_wallet_outlined, size: 18),
          onPressed: () => context.push('/settings/payout'),
        ),
        const SizedBox(height: 24),
        const SectionLabel('Transaction history'),
        const SizedBox(height: 10),
        SegmentedButton<_WalletFilter>(
          segments: const [
            ButtonSegment(value: _WalletFilter.all, label: Text('All')),
            ButtonSegment(
              value: _WalletFilter.entryFees,
              label: Text('Entry fees'),
            ),
            ButtonSegment(value: _WalletFilter.prizes, label: Text('Prizes')),
          ],
          selected: {filter},
          onSelectionChanged: (selection) => onFilter(selection.first),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No transactions in this category yet.',
              textAlign: TextAlign.center,
              style: LbType.bodySm,
            ),
          )
        else
          for (final transaction in visible) ...[
            _TransactionRow(transaction: transaction),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.wallet});
  final LbWallet wallet;

  @override
  Widget build(BuildContext context) {
    final net = wallet.netCashFlowCentavos;
    return LbCard(
      highlighted: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET TOURNAMENT CASH FLOW', style: LbType.sectionLabel),
          const SizedBox(height: 7),
          Text(
            _signedPeso(net),
            key: const Key('wallet-net-cash-flow'),
            style: LbType.rankNumeral(
              32,
              color: net >= 0 ? LbColors.lime : LbColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'PRIZES PAID',
                  centavos: wallet.totalPrizeCentavos,
                  color: LbColors.lime,
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'ENTRY FEES',
                  centavos: wallet.totalEntryFeeCentavos,
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'PENDING',
                  centavos: wallet.pendingPrizeCentavos,
                  color: LbColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.centavos,
    this.color,
  });
  final String label;
  final int centavos;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: LbType.metaSm),
      const SizedBox(height: 5),
      Text(
        _peso(centavos),
        style: LbType.money.copyWith(color: color ?? LbColors.textPrimary),
      ),
    ],
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});
  final LbWalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final incoming = transaction.isIncoming;
    final label = switch (transaction.kind) {
      LbWalletTransactionKind.entryFee => 'ENTRY FEE',
      LbWalletTransactionKind.prize => 'PRIZE PAYOUT',
      LbWalletTransactionKind.refund => 'REFUND',
    };
    return LbCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (incoming ? LbColors.lime : LbColors.surfaceHi).withValues(
                alpha: incoming ? 0.12 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: incoming ? LbColors.lime : LbColors.textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.tournamentTitle,
                  style: LbType.cardTitleSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$label · ${transaction.method.toUpperCase()} · ${transaction.status.toUpperCase()}',
                  style: LbType.metaSm,
                ),
                const SizedBox(height: 2),
                Text(_shortDate(transaction.occurredAt), style: LbType.bodyXs),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _signedPeso(transaction.amountCentavos),
            style: LbType.money.copyWith(
              color: incoming ? LbColors.lime : LbColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

String _peso(int centavos) => formatPeso(centavos / 100, decimals: 2);

String _signedPeso(int centavos) {
  final sign = centavos > 0
      ? '+'
      : centavos < 0
      ? '-'
      : '';
  return '$sign${_peso(centavos.abs())}';
}

String _shortDate(DateTime value) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final local = value.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
