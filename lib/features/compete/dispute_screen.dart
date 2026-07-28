import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/team_avatar.dart';

/// Compete · Dispute submission. Opens a Critical (priority 1) moderator
/// queue item with a 15-minute SLA (spec §3.1). Reachable from a match card
/// or a "dispute opened" notification.
class DisputeScreen extends ConsumerStatefulWidget {
  const DisputeScreen({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends ConsumerState<DisputeScreen> {
  DisputeReason? _reason;
  final _detailCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _reason != null && _detailCtrl.text.trim().length >= 20;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(resultsRepoProvider)
          .openDispute(
            matchId: widget.matchId,
            reason: '${_reason!.name}: ${_detailCtrl.text.trim()}',
          );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: LbColors.surface,
          title: const Text('Dispute submitted'),
          content: const Text(
            'Both team captains have been notified. A moderator will review within 15 minutes. You\'ll get a push either way.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dispute. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Open dispute'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(child: StatusPill.sla(label: '15m SLA')),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
              children: [
                _MatchContextCard(),
                const SizedBox(height: 14),
                _CriticalBanner(),
                const SizedBox(height: 14),
                const SectionLabel('Reason'),
                const SizedBox(height: 8),
                for (final r in DisputeReason.values) ...[
                  _ReasonTile(
                    reason: r,
                    selected: _reason == r,
                    onTap: () => setState(() => _reason = r),
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 14),
                const SectionLabel('Detail', trailing: _MinLenHint()),
                const SizedBox(height: 8),
                TextField(
                  controller: _detailCtrl,
                  onChanged: (_) => setState(() {}),
                  maxLines: 5,
                  minLines: 4,
                  style: LbType.body,
                  decoration: const InputDecoration(
                    hintText:
                        'What happened? Timestamps, in-game screenshots, replay clips — anything the moderator needs.',
                  ),
                ),
                const SizedBox(height: 12),
                _EvidenceHint(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SubmitCta(
              busy: _submitting,
              onPressed: _valid && !_submitting ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}

enum DisputeReason {
  scoreWrong('Score is wrong', 'Reported score doesn\'t match what happened.'),
  noShow('Opponent no-show', 'Team didn\'t show up within the grace window.'),
  cheating(
    'Cheating suspected',
    'Hacks, wallhacks, scripts, or macros observed.',
  ),
  technicalIssue(
    'Technical issue',
    'Server, client, or lag that materially affected the match outcome.',
  ),
  ruleViolation(
    'Rule violation',
    'Tournament-specific rule (region, hero pool, patch version) was broken.',
  ),
  other('Other', 'Doesn\'t fit the categories above.');

  const DisputeReason(this.displayName, this.hint);
  final String displayName;
  final String hint;
}

class _MatchContextCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUARTERFINAL · BEST OF 3 · SUBMITTED 4m AGO',
            style: LbType.metaSm.copyWith(
              color: LbColors.textDim,
              fontSize: 9.5,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    TeamAvatar(code: 'MNL'),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Team MNL · 2',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LbColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'VS',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  letterSpacing: 1,
                  fontSize: 10,
                ),
              ),
              const Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        '1 · Davao GG',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: LbColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    TeamAvatar(code: 'DVO'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CriticalBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LbColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: LbColors.danger.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: LbColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This becomes a Critical moderator item',
                  style: LbType.cardTitleSm.copyWith(color: LbColors.danger),
                ),
                const SizedBox(height: 2),
                Text(
                  'Resolves within 15 minutes. False disputes count toward reputation review.',
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

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final DisputeReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      highlighted: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: selected ? LbColors.lime : Colors.transparent,
              border: Border.all(
                color: selected ? LbColors.lime : LbColors.border,
                width: 1.5,
              ),
              shape: BoxShape.circle,
            ),
            child: selected
                ? const Icon(Icons.circle, size: 8, color: LbColors.limeInk)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason.displayName, style: LbType.cardTitleSm),
                Text(
                  reason.hint,
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

class _MinLenHint extends StatelessWidget {
  const _MinLenHint();
  @override
  Widget build(BuildContext context) => Text(
    'MIN 20 CHARS',
    style: LbType.metaSm.copyWith(color: LbColors.textDim, fontSize: 9),
  );
}

class _EvidenceHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LbColors.bgAlt,
        border: Border.all(color: LbColors.borderMuted),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: LbColors.textDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Moderator sees your original result screenshot + the opponent\'s submission side-by-side. Attach more evidence in-thread once the dispute opens.',
              style: LbType.bodyXs.copyWith(color: LbColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitCta extends StatelessWidget {
  const _SubmitCta({required this.busy, required this.onPressed});
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
              label: busy ? 'Opening…' : 'Open dispute',
              color: LbColors.danger,
              foreground: Colors.white,
              onPressed: onPressed,
              trailing: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
