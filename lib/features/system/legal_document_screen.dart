import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

enum LegalDocument { privacy, terms, tournamentRules, sponsorshipTerms }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final title = switch (document) {
      LegalDocument.privacy => 'Privacy policy',
      LegalDocument.terms => 'Terms of service',
      LegalDocument.tournamentRules => 'Tournament rules',
      LegalDocument.sponsorshipTerms => 'Sponsorship terms',
    };
    final content = switch (document) {
      LegalDocument.privacy => _privacy,
      LegalDocument.terms => _terms,
      LegalDocument.tournamentRules => _tournamentRules,
      LegalDocument.sponsorshipTerms => _sponsorshipTerms,
    };
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Text(
            'DRAFT · JULY 2026',
            style: LbType.metaSm.copyWith(color: LbColors.lime),
          ),
          const SizedBox(height: 12),
          Text(content, style: LbType.bodySm.copyWith(height: 1.6)),
        ],
      ),
    );
  }

  static const _privacy = '''
Labaan collects the account details you provide, your Firebase sign-in identifiers, tournament activity, team membership, results, notification preferences, and payout destination.

We use this information to operate tournaments, prevent fraud, calculate rankings, deliver notifications, and process eligible payouts. Your public profile may show your handle, region, games, rank, badges, teams, and tournament history.

Sensitive account and payout settings are restricted to your authenticated account through database access policies. We do not sell personal information. Service providers such as Firebase, Supabase, and payment partners process data only to provide their contracted services.

You may update your profile and communication preferences in Settings. Account deletion has a 30-day cancellation period. After processing, Firebase sign-in and direct profile and payout identifiers are erased. Payment, payout, tournament, dispute, and audit records may remain pseudonymized for up to five years where needed for financial integrity, legal claims, and compliance. Team ownership and unsettled payouts are reviewed before cleanup.

This draft must be reviewed by Philippine privacy counsel before production release.''';

  static const _terms = '''
Labaan operates skill-based tournaments using two separate closed-loop units. Credits may pay tournament entry fees. Victory Points are earned rewards spendable only on eligible Shop products. Neither unit can be withdrawn, transferred, resold, or converted to money or to the other unit.

Tournament capacity, minimum-start rule, Credit fee, reward formula, cap, placement split, lock time, format, and underfill behavior are shown before registration. Entry fees do not create cash prizes. Results may be reviewed through the evidence, dispute, and moderation process.

Credits, Victory Points, ranks, badges, and Shop entitlements have no cash value. Provider refunds, payment reversals, fraud signals, or rule violations may freeze spending or require manual review.

Labaan may restrict accounts that violate tournament integrity or applicable law. Material disputes and refund rights remain subject to Philippine law and the final production terms.

These are draft MVP terms and must be reviewed by Philippine gaming and consumer-protection counsel before production release.''';

  static const _tournamentRules = '''
Credits and Victory Points are separate, non-cashable units. A registration is confirmed only when the server records the Credit debit. Cancellation returns the exact fee through a new wallet transaction.

Every tournament publishes its capacity, minimum confirmed teams, underfill action, bracket format, reward rate, cap, and placement split before registration. It may start below capacity when the minimum is met. The final Victory Point pool is based on confirmed eligible teams at lock plus verified sponsor allocations, subject to the published cap.

Only verified results and the locked eligible roster can receive rewards. Players must use their own account, submit truthful evidence, and avoid cheating, collusion, harassment, account sharing, automation abuse, and payment abuse. Disputes use Labaan’s evidence and moderator process.

The Shop excludes cash, wallet vouchers, gift cards, cash equivalents, resale, and randomized loot boxes. Eligible pre-delivery cancellation restores Victory Points through a compensating wallet transaction.

This product-rule draft remains subject to each tournament’s published rules, final Terms, publisher rules, and legal review.''';

  static const _sponsorshipTerms = '''
Approved organizers may sponsor an eligible Wallet tournament through the web Host portal. Package price, Victory Point allocation, limits, cap, attribution, and cancellation policy are shown before checkout.

Payment is made to Labaan. Only a verified signed provider event activates the tournament allocation. Sponsorship never credits an organizer wallet and cannot be transferred, withdrawn, resold, or assigned to a chosen winner. Labaan awards the locked pool from verified results.

Before reward lock, an eligible cancellation requests a full refund to the original payment method. After lock, exceptional resolution requires manual review. Provider failures, mismatches, refunds, chargebacks, and abuse signals may also require review.

Organizers must use authorized funds and branding, disclose material sponsor relationships, and comply with publisher, advertising, tournament, and Philippine law. Production use requires provider approval and final legal terms.''';
}
