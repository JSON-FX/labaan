import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

enum LegalDocument { privacy, terms }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final privacy = document == LegalDocument.privacy;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: Text(privacy ? 'Privacy policy' : 'Terms of service'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Text(
            'DRAFT · JULY 2026',
            style: LbType.metaSm.copyWith(color: LbColors.lime),
          ),
          const SizedBox(height: 12),
          Text(
            privacy ? _privacy : _terms,
            style: LbType.bodySm.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  static const _privacy = '''
Labaan collects the account details you provide, your Firebase sign-in identifiers, tournament activity, team membership, results, notification preferences, and payout destination.

We use this information to operate tournaments, prevent fraud, calculate rankings, deliver notifications, and process eligible payouts. Your public profile may show your handle, region, games, rank, badges, teams, and tournament history.

Sensitive account and payout settings are restricted to your authenticated account through database access policies. We do not sell personal information. Service providers such as Firebase, Supabase, and payment partners process data only to provide their contracted services.

You may update your profile and communication preferences in Settings. Account-deletion requests require support review while payment, fraud-prevention, and regulatory retention obligations are checked.

This draft must be reviewed by Philippine privacy counsel before production release.''';

  static const _terms = '''
Labaan is a tournament marketplace. You must provide accurate account information, follow tournament rules, submit truthful results, and avoid cheating, harassment, collusion, chargeback abuse, and account sharing.

Entry fees, platform fees, prize pools, lock times, formats, and payout conditions are shown before registration. Tournament results may be reviewed through the dispute and moderation process.

Ranks and badges are platform progression indicators and have no cash value. Payouts require a valid destination matching the recipient and may be delayed for verification, disputes, or compliance review.

Labaan may restrict accounts that violate tournament integrity or applicable law. Material disputes and refund rights remain subject to Philippine law and the final production terms.

These are draft MVP terms and must be reviewed by Philippine gaming and consumer-protection counsel before production release.''';
}
