import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/slant_button.dart';

/// Post-registration payment result screen. Route param `status` picks one
/// of three variants that PayMongo's webhook can leave the client in:
/// `success` (slot reserved), `pending` (async settlement), `failed` (retry).
///
/// Reachable via `/register/result/success|pending|failed?tournament=…`.
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({
    required this.status,
    this.tournamentTitle = 'Manila Ascent Cup S3',
    this.amount = '₱500.00',
    this.reference,
    super.key,
  });

  final PaymentResult status;
  final String tournamentTitle;
  final String amount;
  final String? reference;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => context.go('/home'),
                ),
              ),
              const Spacer(),
              _StatusIcon(status: status),
              const SizedBox(height: 24),
              Text(
                _titleFor(status),
                textAlign: TextAlign.center,
                style: LbType.takeoverTitle.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitleFor(status),
                textAlign: TextAlign.center,
                style: LbType.bodySm.copyWith(color: LbColors.textMuted),
              ),
              const SizedBox(height: 24),
              _ReceiptCard(
                tournamentTitle: tournamentTitle,
                amount: amount,
                reference: reference ?? 'pi_stub_${status.name}',
                status: status,
              ),
              const Spacer(),
              _ActionsRow(status: status),
              const SizedBox(height: 8),
              if (status != PaymentResult.failed)
                Text(
                  'PayMongo · BSP-registered · GAB compliant',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textDim,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum PaymentResult { success, pending, failed }

String _titleFor(PaymentResult s) => switch (s) {
  PaymentResult.success => 'You\'re in.',
  PaymentResult.pending => 'Processing payment',
  PaymentResult.failed => 'Payment failed',
};

String _subtitleFor(PaymentResult s) => switch (s) {
  PaymentResult.success =>
    'Slot reserved. You\'ll get a push when the bracket locks.',
  PaymentResult.pending =>
    'PayMongo is confirming with your bank. Usually under a minute — we\'ll notify you when the slot is reserved.',
  PaymentResult.failed =>
    'Nothing was charged. Try a different method or retry the same one.',
};

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final PaymentResult status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (status) {
      PaymentResult.success => (
        Icons.check_rounded,
        LbColors.lime,
        LbColors.lime.withValues(alpha: 0.12),
      ),
      PaymentResult.pending => (
        Icons.hourglass_top_rounded,
        LbColors.gold,
        LbColors.gold.withValues(alpha: 0.14),
      ),
      PaymentResult.failed => (
        Icons.close_rounded,
        LbColors.danger,
        LbColors.danger.withValues(alpha: 0.12),
      ),
    };
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 26,
            spreadRadius: -4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 48),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.tournamentTitle,
    required this.amount,
    required this.reference,
    required this.status,
  });

  final String tournamentTitle;
  final String amount;
  final String reference;
  final PaymentResult status;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (status) {
      PaymentResult.success => ('PAID · SLOT RESERVED', LbColors.lime),
      PaymentResult.pending => ('AWAITING SETTLEMENT', LbColors.gold),
      PaymentResult.failed => ('NOT CHARGED', LbColors.danger),
    };
    return LbCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOURNAMENT',
                      style: LbType.metaSm.copyWith(
                        color: LbColors.textDim,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(tournamentTitle, style: LbType.cardTitleSm),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'AMOUNT',
                    style: LbType.metaSm.copyWith(
                      color: LbColors.textDim,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    amount,
                    style: LbType.rankNumeral(15, color: LbColors.lime),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20, color: LbColors.borderMuted),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STATUS',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
              Text(
                statusLabel,
                style: LbType.metaSm.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REFERENCE',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
              Text(
                reference,
                style: LbType.metaSm.copyWith(
                  color: LbColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.status});
  final PaymentResult status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case PaymentResult.success:
        return Row(
          children: [
            Expanded(
              child: SlantButton(
                label: 'View bracket',
                onPressed: () => context.go('/compete'),
              ),
            ),
            const SizedBox(width: 8),
            GhostButton(label: 'Home', onPressed: () => context.go('/home')),
          ],
        );
      case PaymentResult.pending:
        return Row(
          children: [
            Expanded(
              child: SlantButton(
                label: 'Back to home',
                onPressed: () => context.go('/home'),
              ),
            ),
          ],
        );
      case PaymentResult.failed:
        return Row(
          children: [
            Expanded(
              child: SlantButton(
                label: 'Retry payment',
                onPressed: () => context.go('/register'),
              ),
            ),
            const SizedBox(width: 8),
            GhostButton(label: 'Home', onPressed: () => context.go('/home')),
          ],
        );
    }
  }
}
