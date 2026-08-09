import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/domain/tournament_tier.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/game_art.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/lb_chip.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../../core/widgets/team_avatar.dart';
import 'payment_checkout_screen.dart';

/// Registration · 1A · Registration & Payment.
///
/// Loads the target [LbTournament] via [tournamentByIdProvider]; derives fees
/// from the tier. Pay CTA calls [RegistrationRepo.register] with a captcha
/// token stub (spec §11 CAPTCHA gate lands with the real integration).
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({this.tournamentId = 't_ascent_s3', super.key});

  final String tournamentId;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  bool _teamMode = false;
  int _payMethod = 0; // 0 GCash, 1 Maya, 2 Card
  bool _submitting = false;

  PayMethod get _selectedMethod =>
      const [PayMethod.gcash, PayMethod.maya, PayMethod.card][_payMethod];

  Future<void> _pay(LbTournament t, LbTeam? selectedTeam) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }
    if (_teamMode && selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join or create a team first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final repo = ref.read(registrationRepoProvider);
    try {
      final checkout = await repo.register(
        tournamentId: t.id,
        userId: user.id,
        teamId: _teamMode ? selectedTeam?.id : null,
        method: _selectedMethod,
        captchaToken: 'stub-captcha',
      );
      final registration = checkout.registration;
      if (checkout.checkoutUrl case final checkoutUrl?) {
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PaymentCheckoutScreen(checkoutUrl: checkoutUrl),
          ),
        );
        return;
      }
      if (!mounted) return;
      final result = switch (registration.paymentStatus) {
        RegistrationPaymentStatus.paid => 'success',
        RegistrationPaymentStatus.pending => 'pending',
        RegistrationPaymentStatus.failed ||
        RegistrationPaymentStatus.refunded => 'failed',
      };
      context.go(
        Uri(
          path: '/register/result/$result',
          queryParameters: {
            'tournamentId': t.id,
            'tournament': t.title,
            'amount': formatPeso(registration.amountPhp),
            if (registration.paymongoRef != null)
              'reference': registration.paymongoRef,
            'registrationId': registration.id,
          },
        ).toString(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start payment: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tournamentByIdProvider(widget.tournamentId));
    final user = ref.watch(currentUserProvider).value;
    final teams = user == null
        ? const <LbTeam>[]
        : ref.watch(teamsForUserProvider(user.id)).value ?? const <LbTeam>[];
    final selectedTeam = teams.isEmpty ? null : teams.first;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Register'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                'STEP 2 / 2',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const _Skeleton(),
        error: (err, _) => _ErrorState(
          message: 'Could not load tournament',
          onRetry: () =>
              ref.invalidate(tournamentByIdProvider(widget.tournamentId)),
        ),
        data: (t) => Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                children: [
                  _TournamentSummary(tournament: t),
                  const SizedBox(height: 14),
                  const SectionLabel('Competing as'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _EntryModeCard(
                          selected: _teamMode,
                          onTap: () {
                            if (selectedTeam == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Join or create a team first.'),
                                ),
                              );
                              return;
                            }
                            setState(() => _teamMode = true);
                          },
                          avatar: TeamAvatar(code: selectedTeam?.tag ?? '—'),
                          title: selectedTeam?.name ?? 'No team',
                          subtitle: selectedTeam == null
                              ? 'SOLO ONLY'
                              : '${selectedTeam.memberCount} PLAYERS',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _EntryModeCard(
                          selected: !_teamMode,
                          onTap: () => setState(() => _teamMode = false),
                          avatar: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: LbColors.textDim,
                                width: 1.5,
                              ),
                            ),
                          ),
                          title: 'Solo queue',
                          subtitle: 'AUTO-FORM',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SectionLabel(
                    'Fee breakdown',
                    trailing: _TransparentTag(),
                  ),
                  const SizedBox(height: 8),
                  _FeeBreakdown(tier: t.tier),
                  const SizedBox(height: 14),
                  const SectionLabel('Payment method'),
                  const SizedBox(height: 8),
                  _PaymentTile(
                    selected: _payMethod == 0,
                    onTap: () => setState(() => _payMethod = 0),
                    code: 'G',
                    title: 'GCash',
                    hint: '· ••7 · most used',
                    gradient: const [LbColors.gcashStart, LbColors.gcashEnd],
                    highlightHint: true,
                  ),
                  const SizedBox(height: 6),
                  _PaymentTile(
                    selected: _payMethod == 1,
                    onTap: () => setState(() => _payMethod = 1),
                    code: 'M',
                    title: 'Maya',
                    hint: '· PayMaya PH',
                    gradient: const [LbColors.mayaStart, LbColors.mayaEnd],
                  ),
                  const SizedBox(height: 6),
                  _PaymentTile(
                    selected: _payMethod == 2,
                    onTap: () => setState(() => _payMethod = 2),
                    code: '▭',
                    title: 'Credit / Debit card',
                    hint: '· Visa · MC',
                    gradient: const [Color(0xFF2A2F3A), Color(0xFF14171E)],
                  ),
                  const SizedBox(height: 10),
                  if (!ref.watch(backendEnabledProvider)) ...[
                    const _MockPaymentNote(),
                    const SizedBox(height: 8),
                  ],
                  const _CaptchaNote(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PayCta(
                tier: t.tier,
                busy: _submitting,
                onPressed: _submitting ? null : () => _pay(t, selectedTeam),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockPaymentNote extends StatelessWidget {
  const _MockPaymentNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LbColors.gold.withValues(alpha: 0.08),
        border: Border.all(color: LbColors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'PAYMONGO TEST MODE · GCash succeeds · Maya stays pending · Card declines',
        style: LbType.metaSm.copyWith(
          color: LbColors.gold,
          fontSize: 9,
          height: 1.4,
        ),
      ),
    );
  }
}

class _CaptchaNote extends StatelessWidget {
  const _CaptchaNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 14,
          color: LbColors.textDim,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'BOT CHECK · verified on submit',
            style: LbType.metaSm.copyWith(
              color: LbColors.textDim,
              fontSize: 9.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TournamentSummary extends StatelessWidget {
  const _TournamentSummary({required this.tournament});
  final LbTournament tournament;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          GameArt(game: tournament.game, width: 64, height: 56, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.title, style: LbType.cardTitle),
                const SizedBox(height: 3),
                Text(
                  '${tournament.game} · ${_formatBadge(tournament.format.name)} · ${tournament.tier.displayName.toUpperCase()}',
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          LbChip(tournament.tier.displayName, tone: tournament.tier.chipTone),
        ],
      ),
    );
  }
}

String _formatBadge(String snake) => switch (snake) {
  'doubleElimination' => 'DBL ELIM',
  'singleElimination' => 'SGL ELIM',
  _ => snake.toUpperCase(),
};

class _EntryModeCard extends StatelessWidget {
  const _EntryModeCard({
    required this.selected,
    required this.onTap,
    required this.avatar,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget avatar;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      highlighted: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(width: 28, height: 28, child: Center(child: avatar)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: LbType.cardTitleSm.copyWith(
                    color: selected
                        ? LbColors.textPrimary
                        : LbColors.textSecondary,
                  ),
                ),
                Text(
                  subtitle,
                  style: LbType.metaSm.copyWith(
                    color: LbColors.textMuted,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransparentTag extends StatelessWidget {
  const _TransparentTag();
  @override
  Widget build(BuildContext context) => Text(
    'TRANSPARENT',
    style: LbType.metaSm.copyWith(color: LbColors.lime, fontSize: 9),
  );
}

class _FeeBreakdown extends StatelessWidget {
  const _FeeBreakdown({required this.tier});
  final TournamentTier tier;

  @override
  Widget build(BuildContext context) {
    final pct = (tier.commissionRate * 100).toStringAsFixed(0);
    return LbCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _FeeRow(
            label: 'Entry fee',
            hint: 'to prize pool',
            amount: formatPeso(tier.entryFeePhp),
          ),
          _FeeRow(
            label: 'Platform commission',
            hint: '$pct%',
            amount: formatPeso(tier.commissionPhp),
            muted: true,
          ),
          _FeeRow(
            label: 'PayMongo processing',
            hint: 'gateway',
            amount: formatPeso(tier.gatewayFeePhp),
            muted: true,
          ),
          const Divider(height: 12, color: LbColors.borderMuted),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You pay', style: LbType.cardTitle),
                    Text(
                      '${formatPeso(tier.prizeContributionPhp, decimals: 0)} to prize pool',
                      style: LbType.metaSm.copyWith(
                        color: LbColors.lime,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              Text(formatPeso(tier.entryFeePhp), style: LbType.moneyBig),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.label,
    required this.hint,
    required this.amount,
    this.muted = false,
  });
  final String label;
  final String hint;
  final String amount;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(label, style: LbType.body),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LbType.metaSm.copyWith(
                      color: LbColors.textDim,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: LbType.money.copyWith(
              color: muted ? LbColors.textMuted : LbColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.selected,
    required this.onTap,
    required this.code,
    required this.title,
    required this.hint,
    required this.gradient,
    this.highlightHint = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String code;
  final String title;
  final String hint;
  final List<Color> gradient;
  final bool highlightHint;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      highlighted: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            alignment: Alignment.center,
            child: Text(
              code,
              style: LbType.rankNumeral(11, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(title, style: LbType.cardTitleSm),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hint,
                    overflow: TextOverflow.ellipsis,
                    style: LbType.metaSm.copyWith(
                      color: highlightHint && selected
                          ? LbColors.lime
                          : LbColors.textDim,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: selected ? LbColors.lime : Colors.transparent,
              border: Border.all(
                color: selected ? LbColors.lime : LbColors.border,
                width: 1.5,
              ),
              shape: BoxShape.circle,
            ),
            child: selected
                ? const Icon(Icons.check, size: 10, color: LbColors.limeInk)
                : null,
          ),
        ],
      ),
    );
  }
}

class _PayCta extends StatelessWidget {
  const _PayCta({
    required this.tier,
    required this.busy,
    required this.onPressed,
  });
  final TournamentTier tier;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            LbColors.bg,
            LbColors.bg.withValues(alpha: 0.9),
            LbColors.bg.withValues(alpha: 0),
          ],
          stops: const [0.55, 0.9, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SlantButton(
              label: busy ? 'Processing…' : 'Pay & reserve slot',
              onPressed: onPressed,
              trailing: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LbColors.limeInk,
                      ),
                    )
                  : Text(
                      formatPeso(tier.entryFeePhp),
                      style: LbType.button.copyWith(color: LbColors.limeInk),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: h,
      decoration: BoxDecoration(
        color: LbColors.surface,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(11),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [block(60), block(60), block(140), block(140)],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: LbColors.danger,
          ),
          const SizedBox(height: 8),
          Text(message, style: LbType.bodySm),
          const SizedBox(height: 12),
          GhostButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}
