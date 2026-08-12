import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/slant_button.dart';

CreditPackPlatform? paymongoTopupPlatform({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) return CreditPackPlatform.web;
  return targetPlatform == TargetPlatform.android
      ? CreditPackPlatform.androidDirect
      : null;
}

class TopupReturnUrls {
  const TopupReturnUrls({required this.success, required this.cancel});

  factory TopupReturnUrls.forPlatform(
    CreditPackPlatform platform, {
    Uri? webBase,
  }) {
    if (platform == CreditPackPlatform.web) {
      final base = webBase ?? Uri.base;
      return TopupReturnUrls(
        success: base.resolve('/wallet?topupResult=pending'),
        cancel: base.resolve('/wallet?topupResult=cancelled'),
      );
    }
    const query = {'purpose': 'credit_topup'};
    return TopupReturnUrls(
      success: Uri(
        scheme: 'labaan',
        host: 'payment',
        path: '/success',
        queryParameters: query,
      ),
      cancel: Uri(
        scheme: 'labaan',
        host: 'payment',
        path: '/cancel',
        queryParameters: query,
      ),
    );
  }

  final Uri success;
  final Uri cancel;
}

class CreditTopupSheet extends ConsumerStatefulWidget {
  const CreditTopupSheet({required this.platform, super.key});

  final CreditPackPlatform platform;

  @override
  ConsumerState<CreditTopupSheet> createState() => _CreditTopupSheetState();
}

class _CreditTopupSheetState extends ConsumerState<CreditTopupSheet> {
  String? _selectedPackId;
  PayMethod _method = PayMethod.gcash;
  String? _idempotencyKey;
  bool _submitting = false;

  void _selectPack(String id) {
    setState(() {
      _selectedPackId = id;
      _idempotencyKey = null;
    });
  }

  void _selectMethod(PayMethod method) {
    setState(() {
      _method = method;
      _idempotencyKey = null;
    });
  }

  Future<void> _startCheckout(LbCreditPack pack) async {
    setState(() => _submitting = true);
    _idempotencyKey ??=
        'credit-topup:${pack.id}:${DateTime.now().microsecondsSinceEpoch}';
    final returnUrls = TopupReturnUrls.forPlatform(widget.platform);
    try {
      final checkout = await ref
          .read(walletRepoProvider)
          .createPaymongoTopup(
            pack: pack,
            method: _method,
            platform: widget.platform,
            idempotencyKey: _idempotencyKey!,
            successUrl: returnUrls.success,
            cancelUrl: returnUrls.cancel,
          );
      if (mounted) Navigator.of(context).pop(checkout);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start the top-up. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(
      creditPackCatalogProvider(
        CreditPackCatalogQuery(
          provider: CreditPackProvider.paymongo,
          platform: widget.platform,
        ),
      ),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: catalog.when(
          loading: () => const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SizedBox(
            height: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Could not load Credit packs.', style: LbType.bodySm),
                TextButton(
                  onPressed: () => ref.invalidate(
                    creditPackCatalogProvider(
                      CreditPackCatalogQuery(
                        provider: CreditPackProvider.paymongo,
                        platform: widget.platform,
                      ),
                    ),
                  ),
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
          ),
          data: (packs) {
            if (packs.isEmpty) {
              return SizedBox(
                height: 260,
                child: Center(
                  child: Text(
                    'Credit top-ups are not available right now.',
                    style: LbType.bodySm,
                  ),
                ),
              );
            }
            final selected = packs.firstWhere(
              (pack) => pack.id == _selectedPackId,
              orElse: () => packs.first,
            );
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Top up Credits',
                          style: LbType.screenTitle,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    'Choose a server-priced pack. Credits appear only after PayMongo confirms payment.',
                    style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  for (final pack in packs) ...[
                    _PackCard(
                      pack: pack,
                      selected: selected.id == pack.id,
                      onTap: _submitting ? null : () => _selectPack(pack.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  Text('PAYMENT METHOD', style: LbType.sectionLabel),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final method in PayMethod.values)
                        ChoiceChip(
                          label: Text(_methodLabel(method)),
                          selected: _method == method,
                          onSelected: _submitting
                              ? null
                              : (_) => _selectMethod(method),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SlantButton(
                    label: 'Continue · ${_formatPeso(selected.priceCentavos)}',
                    onPressed: _submitting
                        ? null
                        : () => _startCheckout(selected),
                    leading: _submitting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline, size: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Credits are non-cashable and can be used for tournament entry fees.',
                    textAlign: TextAlign.center,
                    style: LbType.metaSm.copyWith(color: LbColors.textMuted),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.selected,
    required this.onTap,
  });

  final LbCreditPack pack;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: LbCard(
      highlighted: selected,
      child: Row(
        children: [
          Icon(
            Icons.toll_outlined,
            color: selected ? LbColors.lime : LbColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${pack.creditAmount} CR', style: LbType.cardTitle),
          ),
          Text(_formatPeso(pack.priceCentavos), style: LbType.money),
          const SizedBox(width: 10),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? LbColors.lime : LbColors.textDim,
            size: 20,
          ),
        ],
      ),
    ),
  );
}

String _methodLabel(PayMethod method) => switch (method) {
  PayMethod.gcash => 'GCash',
  PayMethod.maya => 'Maya',
  PayMethod.card => 'Card',
};

String _formatPeso(int centavos) {
  final pesos = centavos ~/ 100;
  final cents = centavos.remainder(100).abs();
  return cents == 0 ? '₱$pesos' : '₱$pesos.${cents.toString().padLeft(2, '0')}';
}
