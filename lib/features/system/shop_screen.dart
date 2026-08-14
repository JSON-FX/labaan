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
import '../../core/widgets/slant_button.dart';

ShopPlatform? shopPlatform({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) return ShopPlatform.web;
  return targetPlatform == TargetPlatform.android
      ? ShopPlatform.androidDirect
      : null;
}

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final Set<String> _busy = {};

  Future<void> _purchase(LbShopProduct product, ShopPlatform platform) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.displayName),
        content: Text(
          '${product.description}\n\nSpend ${product.priceRewardPoints} Victory Points? '
          'This item is not cashable or transferable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(product.id));
    try {
      await ref
          .read(shopRepoProvider)
          .purchase(
            product: product,
            platform: platform,
            quantity: 1,
            idempotencyKey:
                'shop:${product.id}:${DateTime.now().microsecondsSinceEpoch}',
          );
      ref.invalidate(walletProvider);
      ref.invalidate(shopOrdersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.displayName} is being prepared.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not complete the purchase. Check your balance.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(product.id));
    }
  }

  Future<void> _cancel(LbShopOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          '${order.totalRewardPoints} Victory Points will return to your Wallet '
          'if fulfillment has not started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP ORDER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CANCEL ORDER'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(order.id));
    try {
      await ref
          .read(shopRepoProvider)
          .cancel(
            orderId: order.id,
            reason: 'Player cancelled before item delivery',
            idempotencyKey:
                'shop-cancel:${order.id}:${DateTime.now().microsecondsSinceEpoch}',
          );
      ref.invalidate(walletProvider);
      ref.invalidate(shopOrdersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled and points returned.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order can no longer be cancelled.')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = shopPlatform(
      isWeb: kIsWeb,
      targetPlatform: defaultTargetPlatform,
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: const Text('Victory Point Shop'),
      ),
      body: platform == null
          ? const _UnavailableShop()
          : RefreshIndicator(
              color: LbColors.lime,
              backgroundColor: LbColors.surface,
              onRefresh: () async {
                ref.invalidate(shopCatalogProvider(platform));
                ref.invalidate(shopOrdersProvider);
                ref.invalidate(walletProvider);
                await Future.wait([
                  ref.read(shopCatalogProvider(platform).future),
                  ref.read(shopOrdersProvider.future),
                  ref.read(walletProvider.future),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                children: [
                  _BalanceCard(wallet: ref.watch(walletProvider)),
                  const SizedBox(height: 18),
                  const SectionLabel('Available items'),
                  const SizedBox(height: 8),
                  ref
                      .watch(shopCatalogProvider(platform))
                      .when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (_, _) => const _ShopMessage(
                          message: 'Could not load the Shop catalog.',
                        ),
                        data: (products) => products.isEmpty
                            ? const _ShopMessage(
                                message: 'No items are available right now.',
                              )
                            : Column(
                                children: [
                                  for (final product in products) ...[
                                    _ProductCard(
                                      product: product,
                                      busy: _busy.contains(product.id),
                                      onBuy: () => _purchase(product, platform),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                      ),
                  const SizedBox(height: 16),
                  const SectionLabel('Your orders'),
                  const SizedBox(height: 8),
                  ref
                      .watch(shopOrdersProvider)
                      .when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (_, _) => const _ShopMessage(
                          message: 'Could not load your Shop orders.',
                        ),
                        data: (orders) => orders.isEmpty
                            ? const _ShopMessage(
                                message: 'Your purchases will appear here.',
                              )
                            : Column(
                                children: [
                                  for (final order in orders) ...[
                                    _OrderCard(
                                      order: order,
                                      busy: _busy.contains(order.id),
                                      onCancel: () => _cancel(order),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});
  final AsyncValue<LbWallet> wallet;

  @override
  Widget build(BuildContext context) => LbCard(
    highlighted: true,
    child: wallet.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Victory Point balance unavailable'),
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AVAILABLE TO SPEND',
            style: LbType.metaSm.copyWith(
              color: LbColors.textDim,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.balanceFor(LbWalletCurrency.rewardPoint)} VP',
            style: LbType.rankNumeral(30, color: LbColors.lime),
          ),
          Text(
            'Earned rewards only · not cashable or transferable',
            style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.busy,
    required this.onBuy,
  });
  final LbShopProduct product;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) => LbCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: LbColors.lime),
            const SizedBox(width: 10),
            Expanded(
              child: Text(product.displayName, style: LbType.cardTitleSm),
            ),
            Text('${product.priceRewardPoints} VP', style: LbType.cardTitleSm),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          product.description,
          style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
        ),
        const SizedBox(height: 12),
        SlantButton(
          label: busy ? 'Processing…' : 'View & redeem',
          onPressed: busy ? null : onBuy,
          height: 42,
        ),
      ],
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onCancel,
  });
  final LbShopOrder order;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => LbCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(order.productName, style: LbType.cardTitleSm)),
            Text('${order.totalRewardPoints} VP', style: LbType.metaSm),
          ],
        ),
        const SizedBox(height: 4),
        Text(order.customerStatus, style: LbType.bodyXs),
        Text(
          order.status.name.replaceAllMapped(
            RegExp(r'[A-Z]'),
            (match) => ' ${match.group(0)!.toLowerCase()}',
          ),
          style: LbType.metaSm.copyWith(color: LbColors.textMuted),
        ),
        if (order.canCancel) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onCancel,
            child: Text(busy ? 'CANCELLING…' : 'CANCEL ORDER'),
          ),
        ],
      ],
    ),
  );
}

class _ShopMessage extends StatelessWidget {
  const _ShopMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => LbCard(
    child: Text(
      message,
      style: LbType.bodySm.copyWith(color: LbColors.textMuted),
    ),
  );
}

class _UnavailableShop extends StatelessWidget {
  const _UnavailableShop();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: const [
      _ShopMessage(
        message:
            'The Victory Point Shop is available only on Labaan web and the direct Android app.',
      ),
    ],
  );
}
