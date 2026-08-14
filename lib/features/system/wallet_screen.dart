import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../registration/payment_checkout_screen.dart';
import 'credit_topup_sheet.dart';
import 'shop_screen.dart';

enum _WalletFilter { all, credits, rewards }

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({this.topupResult, super.key});

  final String? topupResult;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _WalletFilter _filter = _WalletFilter.all;

  @override
  void initState() {
    super.initState();
    if (widget.topupResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTopupReturn());
    }
  }

  Future<void> _handleTopupReturn() async {
    if (!mounted) return;
    final pending = widget.topupResult == 'pending';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pending
              ? 'Payment received. Waiting for PayMongo confirmation.'
              : 'Top-up checkout was cancelled.',
        ),
      ),
    );
    if (!pending) return;

    // The return URL is navigation only. Poll the authoritative wallet while
    // the signed webhook finishes, without ever granting value client-side.
    for (var attempt = 0; attempt < 5 && mounted; attempt++) {
      ref.invalidate(walletProvider);
      try {
        await ref.read(walletProvider.future);
      } catch (_) {
        // Pull-to-refresh remains available if a transient read fails.
      }
      if (attempt < 4) await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _openTopup(CreditPackPlatform platform) async {
    final checkout = await showModalBottomSheet<LbTopupCheckout>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LbColors.surface,
      builder: (_) => CreditTopupSheet(platform: platform),
    );
    if (checkout == null || !mounted) return;

    if (kIsWeb) {
      final opened = await launchUrl(
        checkout.checkoutUrl,
        webOnlyWindowName: '_self',
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PayMongo Checkout.')),
        );
      }
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            PaymentCheckoutScreen(checkoutUrl: checkout.checkoutUrl),
      ),
    );
    if (!mounted) return;
    ref.invalidate(walletProvider);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final features = ref.watch(economyFeaturesProvider).asData?.value;
    final topupPlatform = paymongoTopupPlatform(
      isWeb: kIsWeb,
      targetPlatform: defaultTargetPlatform,
    );
    final currentShopPlatform = shopPlatform(
      isWeb: kIsWeb,
      targetPlatform: defaultTargetPlatform,
    );
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
            onTopup:
                topupPlatform == null ||
                    !(features?.isEnabled(LbEconomyFeature.creditTopup) ??
                        false)
                ? null
                : () => unawaited(_openTopup(topupPlatform)),
            onShop:
                currentShopPlatform == null ||
                    !(features?.isEnabled(LbEconomyFeature.shop) ?? false)
                ? null
                : () => context.push('/shop'),
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
    required this.onTopup,
    required this.onShop,
  });

  final LbWallet wallet;
  final _WalletFilter filter;
  final ValueChanged<_WalletFilter> onFilter;
  final VoidCallback? onTopup;
  final VoidCallback? onShop;

  @override
  Widget build(BuildContext context) {
    final visible = wallet.transactions.where((transaction) {
      return switch (filter) {
        _WalletFilter.all => true,
        _WalletFilter.credits =>
          transaction.currency == LbWalletCurrency.entryCredit,
        _WalletFilter.rewards =>
          transaction.currency == LbWalletCurrency.rewardPoint,
      };
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        _BalancesCard(wallet: wallet),
        if (onTopup != null) ...[
          const SizedBox(height: 12),
          SlantButton(
            label: 'Top up Credits',
            onPressed: onTopup,
            leading: const Icon(Icons.add_circle_outline, size: 18),
          ),
        ],
        if (onShop != null) ...[
          const SizedBox(height: 8),
          GhostButton(label: 'Open Victory Point Shop', onPressed: onShop),
        ],
        const SizedBox(height: 12),
        Text(
          'Credits pay tournament entry fees. Victory Points are earned as rewards and can be spent in the Shop. Neither balance is cash or withdrawable.',
          style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
        ),
        const SizedBox(height: 24),
        const SectionLabel('Transaction history'),
        const SizedBox(height: 10),
        SegmentedButton<_WalletFilter>(
          segments: const [
            ButtonSegment(value: _WalletFilter.all, label: Text('All')),
            ButtonSegment(value: _WalletFilter.credits, label: Text('Credits')),
            ButtonSegment(value: _WalletFilter.rewards, label: Text('Rewards')),
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

class _BalancesCard extends StatelessWidget {
  const _BalancesCard({required this.wallet});

  final LbWallet wallet;

  @override
  Widget build(BuildContext context) {
    final credits = wallet.balanceFor(LbWalletCurrency.entryCredit);
    final rewards = wallet.balanceFor(LbWalletCurrency.rewardPoint);
    return LbCard(
      highlighted: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AVAILABLE BALANCES', style: LbType.sectionLabel),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BalanceValue(
                  balance: credits,
                  icon: Icons.sports_esports_outlined,
                  color: LbColors.lime,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _BalanceValue(
                  balance: rewards,
                  icon: Icons.emoji_events_outlined,
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

class _BalanceValue extends StatelessWidget {
  const _BalanceValue({
    required this.balance,
    required this.icon,
    required this.color,
  });

  final LbWalletBalance balance;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.28)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 12),
        Text(
          '${_wholeUnits(balance.balance)} ${balance.symbol}',
          key: Key('wallet-balance-${balance.currency.name}'),
          style: LbType.rankNumeral(25, color: color),
        ),
        const SizedBox(height: 4),
        Text(balance.displayName.toUpperCase(), style: LbType.metaSm),
      ],
    ),
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final LbWalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final incoming = transaction.isIncoming;
    final label = switch (transaction.kind) {
      LbWalletTransactionKind.topup => 'TOP UP',
      LbWalletTransactionKind.entryFee => 'ENTRY FEE',
      LbWalletTransactionKind.entryRefund => 'ENTRY REFUND',
      LbWalletTransactionKind.providerReversal => 'PAYMENT REVERSAL',
      LbWalletTransactionKind.rewardAllocation => 'PRIZE POOL',
      LbWalletTransactionKind.rewardGrant => 'REWARD',
      LbWalletTransactionKind.shopPurchase => 'SHOP PURCHASE',
      LbWalletTransactionKind.shopRefund => 'SHOP REFUND',
      LbWalletTransactionKind.adminAdjustment => 'BALANCE ADJUSTMENT',
    };
    final symbol = transaction.currency == LbWalletCurrency.entryCredit
        ? 'CR'
        : 'VP';
    final currencyName = transaction.currency == LbWalletCurrency.entryCredit
        ? 'Credits'
        : 'Victory Points';
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
                Text(label, style: LbType.cardTitleSm),
                const SizedBox(height: 3),
                Text(
                  '$currencyName · ${_shortDate(transaction.occurredAt)}',
                  style: LbType.metaSm,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${incoming ? '+' : '-'}${_wholeUnits(transaction.amount.abs())} $symbol',
            style: LbType.money.copyWith(
              color: incoming ? LbColors.lime : LbColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

String _wholeUnits(int value) {
  final digits = value.abs().toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(',');
    output.write(digits[index]);
  }
  return '${value < 0 ? '-' : ''}$output';
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
