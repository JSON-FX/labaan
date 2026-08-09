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
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/team_avatar.dart';

class ResultVerificationScreen extends ConsumerStatefulWidget {
  const ResultVerificationScreen({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<ResultVerificationScreen> createState() =>
      _ResultVerificationScreenState();
}

class _ResultVerificationScreenState
    extends ConsumerState<ResultVerificationScreen> {
  bool _confirmed = false;
  bool _submitting = false;

  Future<void> _verify() async {
    setState(() => _submitting = true);
    try {
      await ref.read(resultsRepoProvider).verify(matchId: widget.matchId);
      if (!mounted) return;
      final user = ref.read(currentUserProvider).value;
      ref.invalidate(matchSubmissionContextProvider(widget.matchId));
      if (user != null) {
        ref.invalidate(myTournamentsProvider(user.id));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result confirmed. Match completed.')),
      );
      context.go('/compete');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not confirm this result. Refresh and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(
      matchSubmissionContextProvider(widget.matchId),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Review Result'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(child: StatusPill.sla(label: '30m SLA')),
          ),
        ],
      ),
      body: submission.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: GhostButton(
            label: 'Retry',
            onPressed: () =>
                ref.invalidate(matchSubmissionContextProvider(widget.matchId)),
          ),
        ),
        data: (value) => _VerificationBody(
          submission: value,
          confirmed: _confirmed,
          submitting: _submitting,
          onConfirmed: (confirmed) => setState(() => _confirmed = confirmed),
          onVerify: _verify,
          onDispute: () => context.push('/dispute/${widget.matchId}'),
        ),
      ),
    );
  }
}

class _VerificationBody extends ConsumerWidget {
  const _VerificationBody({
    required this.submission,
    required this.confirmed,
    required this.submitting,
    required this.onConfirmed,
    required this.onVerify,
    required this.onDispute,
  });

  final LbMatchSubmissionContext submission;
  final bool confirmed;
  final bool submitting;
  final ValueChanged<bool> onConfirmed;
  final VoidCallback onVerify;
  final VoidCallback onDispute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = submission.match;
    final submittedTeam = match.submittedTeamId == submission.teamA.id
        ? submission.teamA
        : submission.teamB;
    final isVerifiable =
        match.status == LbMatchStatus.awaitingVerification &&
        match.screenshotUrl != null;
    final evidence = match.screenshotUrl == null
        ? const AsyncData<String?>(null)
        : ref.watch(matchEvidenceUrlProvider(match.screenshotUrl!));

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 136),
            children: [
              LbCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROUND ${match.round} · SUBMITTED BY ${submittedTeam.tag}',
                      style: LbType.metaSm.copyWith(
                        color: LbColors.textDim,
                        fontSize: 9.5,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TeamScore(
                            team: submission.teamA.name,
                            tag: submission.teamA.tag,
                            score: match.scoreA,
                            winner: match.scoreA > match.scoreB,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'VS',
                            style: LbType.metaSm.copyWith(
                              color: LbColors.textDim,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _TeamScore(
                            team: submission.teamB.name,
                            tag: submission.teamB.tag,
                            score: match.scoreB,
                            winner: match.scoreB > match.scoreA,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionLabel('Submitted evidence'),
              const SizedBox(height: 8),
              _EvidenceCard(evidence: evidence),
              const SizedBox(height: 16),
              const SectionLabel('Your decision'),
              const SizedBox(height: 8),
              LbCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm only if the score and screenshot match the game you played.',
                      style: LbType.bodySm.copyWith(
                        color: LbColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: isVerifiable
                          ? () => onConfirmed(!confirmed)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: confirmed,
                              onChanged: isVerifiable
                                  ? (value) => onConfirmed(value ?? false)
                                  : null,
                              activeColor: LbColors.lime,
                              checkColor: LbColors.limeInk,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'I confirm this final score is accurate.',
                                style: LbType.cardTitleSm,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: LbColors.bg.withValues(alpha: 0.96),
              boxShadow: const [
                BoxShadow(color: LbColors.bg, blurRadius: 18, spreadRadius: 10),
              ],
            ),
            child: Column(
              children: [
                SlantButton(
                  label: submitting ? 'Confirming…' : 'Confirm result',
                  onPressed: confirmed && isVerifiable && !submitting
                      ? onVerify
                      : null,
                  trailing: const Icon(Icons.check_rounded, size: 18),
                ),
                const SizedBox(height: 8),
                GhostButton(
                  label: 'Open dispute',
                  onPressed: submitting ? null : onDispute,
                  height: 40,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.team,
    required this.tag,
    required this.score,
    required this.winner,
  });

  final String team;
  final String tag;
  final int score;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamAvatar(code: tag, size: 46),
        const SizedBox(height: 6),
        Text(
          team,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LbType.cardTitleSm,
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: LbType.rankNumeral(
            34,
            color: winner ? LbColors.lime : LbColors.textSecondary,
          ),
        ),
        Text(
          winner ? 'WINNER' : 'FINAL',
          style: LbType.metaSm.copyWith(
            color: winner ? LbColors.lime : LbColors.textDim,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.evidence});

  final AsyncValue<String?> evidence;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 210,
        width: double.infinity,
        child: evidence.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const _EvidenceFallback(label: 'Evidence preview unavailable'),
          data: (url) => url == null
              ? const _EvidenceFallback(label: 'Screenshot attached')
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _EvidenceFallback(
                      label: 'Evidence preview unavailable',
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _EvidenceFallback extends StatelessWidget {
  const _EvidenceFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, color: LbColors.lime, size: 34),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), style: LbType.metaSm),
        ],
      ),
    );
  }
}
