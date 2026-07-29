import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/slant_button.dart';

/// First-run identity setup — spec §7.1 Onboarding notes call this out. Runs
/// after OAuth returns a user with [LbUser.hasCompletedSetup] = false.
///
/// Three steps: username → region → games. Submits through
/// [AuthRepo.completeFirstRunSetup] and routes to /home.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 0;
  final _usernameCtrl = TextEditingController();
  String? _region;
  final Set<String> _games = {};
  bool _submitting = false;

  static const _regions = [
    'Manila',
    'Cebu',
    'Cavite',
    'Davao',
    'Iloilo',
    'Baguio',
    'CDO',
    'Zamboanga',
  ];

  static const _availableGames = [
    'MLBB',
    'VALORANT',
    'COD Mobile',
    'PUBG',
    'TEKKEN 8',
  ];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  bool get _stepValid => switch (_step) {
    0 => _usernameCtrl.text.trim().length >= 3,
    1 => _region != null,
    2 => _games.isNotEmpty,
    _ => false,
  };

  Future<void> _next() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepoProvider)
          .completeFirstRunSetup(
            username: '@${_usernameCtrl.text.trim().replaceFirst("@", "")}',
            region: _region!,
            games: _games.toList(),
          );
      if (!mounted) return;
      // Firebase auth itself did not change, but its mapped Supabase profile
      // did. Restart the session stream so Home reads the completed profile.
      ref.invalidate(currentUserProvider);
      context.go('/home');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Setup failed. Try again.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                onPressed: _back,
              )
            : null,
        title: const Text('Set up your identity'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                'STEP ${_step + 1} / 3',
                style: LbType.metaSm.copyWith(
                  color: LbColors.textDim,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
              child: _StepBody(
                step: _step,
                usernameCtrl: _usernameCtrl,
                onUsernameChange: (_) => setState(() {}),
                region: _region,
                onRegion: (r) => setState(() => _region = r),
                games: _games,
                onToggleGame: (g) => setState(() {
                  _games.contains(g) ? _games.remove(g) : _games.add(g);
                }),
                regions: _regions,
                availableGames: _availableGames,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _NextCta(
              label: _step == 2
                  ? (_submitting ? 'Finishing…' : 'Finish')
                  : 'Continue',
              busy: _submitting,
              onPressed: _stepValid && !_submitting ? _next : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.usernameCtrl,
    required this.onUsernameChange,
    required this.region,
    required this.onRegion,
    required this.games,
    required this.onToggleGame,
    required this.regions,
    required this.availableGames,
  });

  final int step;
  final TextEditingController usernameCtrl;
  final ValueChanged<String> onUsernameChange;
  final String? region;
  final ValueChanged<String> onRegion;
  final Set<String> games;
  final ValueChanged<String> onToggleGame;
  final List<String> regions;
  final List<String> availableGames;

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:
        return _UsernameStep(
          controller: usernameCtrl,
          onChange: onUsernameChange,
        );
      case 1:
        return _RegionStep(value: region, onChange: onRegion, regions: regions);
      case 2:
      default:
        return _GamesStep(
          selected: games,
          onToggle: onToggleGame,
          availableGames: availableGames,
        );
    }
  }
}

class _UsernameStep extends StatelessWidget {
  const _UsernameStep({required this.controller, required this.onChange});
  final TextEditingController controller;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Pick your handle',
          style: LbType.sectionTitle.copyWith(
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This is what recruiters see. 3+ characters, letters, numbers, or underscores.',
          style: LbType.bodySm.copyWith(color: LbColors.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          onChanged: onChange,
          style: LbType.sectionTitle.copyWith(letterSpacing: 0),
          decoration: const InputDecoration(
            prefixText: '@',
            hintText: 'yourhandle',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Must be unique across Labaan.',
          style: LbType.metaSm.copyWith(color: LbColors.textDim, fontSize: 10),
        ),
      ],
    );
  }
}

class _RegionStep extends StatelessWidget {
  const _RegionStep({
    required this.value,
    required this.onChange,
    required this.regions,
  });
  final String? value;
  final ValueChanged<String> onChange;
  final List<String> regions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Where do you compete from?',
          style: LbType.sectionTitle.copyWith(
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Used for local brackets and regional leaderboards.',
          style: LbType.bodySm.copyWith(color: LbColors.textMuted),
        ),
        const SizedBox(height: 16),
        SectionLabel('PH regions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in regions)
              GestureDetector(
                onTap: () => onChange(r),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: value == r ? LbColors.lime : LbColors.surface,
                    border: Border.all(
                      color: value == r ? LbColors.lime : LbColors.border,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r.toUpperCase(),
                    style: LbType.cardTitleSm.copyWith(
                      color: value == r
                          ? LbColors.limeInk
                          : LbColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GamesStep extends StatelessWidget {
  const _GamesStep({
    required this.selected,
    required this.onToggle,
    required this.availableGames,
  });
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final List<String> availableGames;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Which games do you play?',
          style: LbType.sectionTitle.copyWith(
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick as many as you like. You can add more later in Settings.',
          style: LbType.bodySm.copyWith(color: LbColors.textMuted),
        ),
        const SizedBox(height: 16),
        for (final g in availableGames)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LbCard(
              highlighted: selected.contains(g),
              onTap: () => onToggle(g),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected.contains(g)
                          ? LbColors.lime
                          : Colors.transparent,
                      border: Border.all(
                        color: selected.contains(g)
                            ? LbColors.lime
                            : LbColors.border,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: selected.contains(g)
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: LbColors.limeInk,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(g, style: LbType.cardTitle),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NextCta extends StatelessWidget {
  const _NextCta({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
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
              label: label,
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
                  : const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: LbColors.limeInk,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
