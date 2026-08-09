import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/team_avatar.dart';

/// Compete · 2A · Result Submission.
///
/// Talks to [ResultsRepo]: requests a pre-signed URL when the user picks a
/// screenshot (spec §11: "screenshot uploads use pre-signed URLs for direct
/// client-to-storage upload — API server never handles file bytes") then
/// posts the score. 30m SLA counts down against the moderator queue.
class ResultSubmissionScreen extends ConsumerStatefulWidget {
  const ResultSubmissionScreen({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<ResultSubmissionScreen> createState() =>
      _ResultSubmissionScreenState();
}

class _ResultSubmissionScreenState
    extends ConsumerState<ResultSubmissionScreen> {
  int _scoreA = 2;
  int _scoreB = 1;
  bool _confirmed = false;
  String? _screenshotPath;
  bool _uploading = false;
  bool _submitting = false;

  Future<void> _pickAndUpload() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot must be 5 MB or smaller.')),
      );
      return;
    }

    final rawExtension = image.name.split('.').last.toLowerCase();
    final extension = rawExtension == 'jpeg' ? 'jpg' : rawExtension;
    final contentType =
        image.mimeType ??
        switch (extension) {
          'jpg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => '',
        };
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(contentType)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a JPG, PNG, or WebP screenshot.')),
      );
      return;
    }

    final repo = ref.read(resultsRepoProvider);
    setState(() => _uploading = true);
    try {
      final path = await repo.uploadScreenshot(
        userId: user.id,
        matchId: widget.matchId,
        bytes: bytes,
        contentType: contentType,
        extension: extension,
      );
      if (!mounted) return;
      setState(() => _screenshotPath = path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot upload failed.')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_screenshotPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attach a proof screenshot first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(resultsRepoProvider)
          .submit(
            matchId: widget.matchId,
            scoreA: _scoreA,
            scoreB: _scoreB,
            screenshotPath: _screenshotPath!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Result sent for moderator verification.'),
        ),
      );
      context.go('/compete');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission failed. Try again.')),
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
        title: const Text('Submit Result'),
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
        data: (value) {
          final canSubmit =
              _confirmed &&
              _scoreA != _scoreB &&
              _screenshotPath != null &&
              !_uploading &&
              !_submitting;
          return Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                  children: [
                    _MatchContextCard(submission: value),
                    const SizedBox(height: 14),
                    const SectionLabel('Final score'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ScoreStepper(
                            team: value.teamA.name.toUpperCase(),
                            value: _scoreA,
                            highlighted: _scoreA > _scoreB,
                            onDecrement: () => setState(
                              () => _scoreA = (_scoreA - 1).clamp(0, 9),
                            ),
                            onIncrement: () => setState(
                              () => _scoreA = (_scoreA + 1).clamp(0, 9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ScoreStepper(
                            team: value.teamB.name.toUpperCase(),
                            value: _scoreB,
                            highlighted: _scoreB > _scoreA,
                            onDecrement: () => setState(
                              () => _scoreB = (_scoreB - 1).clamp(0, 9),
                            ),
                            onIncrement: () => setState(
                              () => _scoreB = (_scoreB + 1).clamp(0, 9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: LbType.metaSm.copyWith(
                            color: LbColors.textMuted,
                            fontSize: 10,
                          ),
                          children: [
                            const TextSpan(text: 'WINNER · '),
                            TextSpan(
                              text: _scoreA == _scoreB
                                  ? 'TIE'
                                  : (_scoreA > _scoreB
                                        ? value.teamA.name.toUpperCase()
                                        : value.teamB.name.toUpperCase()),
                              style: LbType.metaSm.copyWith(
                                color: LbColors.lime,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SectionLabel('Proof screenshot'),
                    const SizedBox(height: 8),
                    _ProofDropzone(
                      uploaded: _screenshotPath != null,
                      uploading: _uploading,
                      onTap: _uploading ? null : _pickAndUpload,
                    ),
                    const SizedBox(height: 14),
                    _ConfirmRow(
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _SubmitCta(
                  busy: _submitting,
                  onPressed: canSubmit ? _submit : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MatchContextCard extends StatelessWidget {
  const _MatchContextCard({required this.submission});

  final LbMatchSubmissionContext submission;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROUND ${submission.match.round} · MATCH RESULT',
            style: LbType.metaSm.copyWith(
              color: LbColors.textDim,
              fontSize: 9.5,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    TeamAvatar(code: submission.teamA.tag),
                    const SizedBox(width: 8),
                    Text(
                      submission.teamA.name,
                      style: const TextStyle(
                        color: LbColors.textPrimary,
                        fontWeight: FontWeight.w700,
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
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      submission.teamB.name,
                      style: const TextStyle(
                        color: LbColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TeamAvatar(code: submission.teamB.tag),
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

class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({
    required this.team,
    required this.value,
    required this.highlighted,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String team;
  final int value;
  final bool highlighted;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      highlighted: highlighted,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(
            team,
            style: LbType.metaSm.copyWith(
              color: LbColors.textDim,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(icon: '−', onTap: onDecrement, primary: false),
              Text(
                '$value',
                style: LbType.rankNumeral(
                  34,
                  color: highlighted ? LbColors.lime : LbColors.textPrimary,
                ),
              ),
              _StepButton(icon: '+', onTap: onIncrement, primary: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.primary,
  });
  final String icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: primary ? LbColors.lime : LbColors.surfaceHi,
          border: Border.all(color: primary ? LbColors.lime : LbColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          icon,
          style: LbType.rankNumeral(
            16,
            color: primary ? LbColors.limeInk : LbColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProofDropzone extends StatelessWidget {
  const _ProofDropzone({
    required this.uploaded,
    required this.uploading,
    required this.onTap,
  });

  final bool uploaded;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 128,
        decoration: BoxDecoration(
          color: uploaded
              ? LbColors.lime.withValues(alpha: 0.06)
              : LbColors.surface,
          border: Border.all(
            color: uploaded ? LbColors.lime : LbColors.border,
            width: uploaded ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: uploaded ? LbColors.lime : LbColors.lime,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: uploading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          color: LbColors.lime,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        uploaded
                            ? Icons.check_rounded
                            : Icons.arrow_upward_rounded,
                        color: LbColors.lime,
                        size: 18,
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                uploading
                    ? 'UPLOADING PROOF…'
                    : uploaded
                    ? 'PROOF ATTACHED · TAP TO REPLACE'
                    : 'TAP TO CHOOSE · MATCH RESULT SCREENSHOT',
                style: LbType.cardTitleSm.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                'JPG, PNG, or WebP · max 5 MB',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return LbCard(
      padding: const EdgeInsets.all(12),
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? LbColors.lime : Colors.transparent,
              border: Border.all(
                color: value ? LbColors.lime : LbColors.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: LbColors.limeInk)
                : null,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'I confirm this score is accurate. Disputes escalate to the '
              'moderator queue and both team captains will be notified.',
              style: TextStyle(fontSize: 11.5, height: 1.45),
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
              label: busy ? 'Submitting…' : 'Submit to moderator',
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
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
