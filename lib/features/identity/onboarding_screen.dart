import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/data/supabase_client.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/slant_button.dart';

/// System · 1A · Onboarding & Sign-in.
///
/// Auth CTAs call [AuthRepo.signInWith*]. The `_busy` flag disables all
/// three buttons during any in-flight sign-in so double-taps can't spawn
/// two parallel auth attempts.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;
  String? _which; // 'google' | 'facebook' | 'phone' — for spinner target

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreSession);
  }

  Future<void> _restoreSession() async {
    if (!ref.read(backendEnabledProvider)) return;
    final user = await ref.read(authRepoProvider).currentUser();
    if (!mounted || user == null) return;
    context.go(user.hasCompletedSetup ? '/home' : '/setup');
  }

  Future<void> _signIn(String provider) async {
    final bypassPhone = provider == 'phone' && Lb.phoneAuthBypass;
    if (provider == 'phone' &&
        !bypassPhone &&
        ref.read(backendEnabledProvider)) {
      context.push('/phone-sign-in');
      return;
    }
    setState(() {
      _busy = true;
      _which = provider;
    });
    try {
      final repo = ref.read(authRepoProvider);
      late final LbUser signedIn;
      switch (provider) {
        case 'google':
          signedIn = await repo.signInWithGoogle();
        case 'facebook':
          signedIn = await repo.signInWithFacebook();
        case 'phone':
          signedIn = bypassPhone
              ? await repo.signInForTesting()
              : await repo.signInWithPhone('+639170000000');
      }
      if (!mounted) return;
      context.go(
        bypassPhone
            ? '/home'
            : (signedIn.hasCompletedSetup ? '/home' : '/setup'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _which = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Text(
                        'LABAAN',
                        style: LbType.wordmark.copyWith(
                          shadows: [
                            Shadow(
                              blurRadius: 24,
                              color: LbColors.lime.withValues(alpha: 0.25),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'FIGHT · WIN · RISE',
                        style: LbType.metaLabel.copyWith(
                          color: LbColors.lime,
                          fontSize: 10,
                          letterSpacing: 5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _HeroArt(),
                  const SizedBox(height: 24),
                  const _ValueBullets(),
                  const Spacer(),
                  _AuthCtas(busy: _busy, active: _which, onSignIn: _signIn),
                  const SizedBox(height: 14),
                  const _ComplianceStrip(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 0.9,
            colors: [LbColors.lime.withValues(alpha: 0.14), LbColors.bg],
            stops: const [0.0, 0.6],
          ),
        ),
      ),
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 160,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LbColors.valStart, LbColors.valMid, LbColors.valEnd],
            ),
          ),
          child: Center(
            child: Text(
              'HERO · CINEMATIC SPLASH',
              style: LbType.metaSm.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueBullets extends StatelessWidget {
  const _ValueBullets();

  static const _items = <(String, String, String)>[
    ('✓', 'Compete', 'Thousands of live tournaments across your games.'),
    (
      '◈',
      'Build a rank',
      'Win to climb 7 tiers — earn badges that recruiters see.',
    ),
    ('₱', 'Win real money', 'Prize peso, paid out via GCash, Maya, or card.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (icon, head, body) in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(color: LbColors.lime, width: 1.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    icon,
                    style: LbType.cardTitleSm.copyWith(color: LbColors.lime),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(head, style: LbType.cardTitleSm),
                      const SizedBox(height: 2),
                      Text(body, style: LbType.bodyXs),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AuthCtas extends StatelessWidget {
  const _AuthCtas({
    required this.busy,
    required this.active,
    required this.onSignIn,
  });

  final bool busy;
  final String? active;
  final Future<void> Function(String provider) onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _oauthButton(
          context,
          label: active == 'google' ? 'SIGNING IN…' : 'CONTINUE WITH GOOGLE',
          badge: 'G',
          badgeColor: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4285F4),
              Color(0xFF34A853),
              Color(0xFFFBBC04),
              Color(0xFFEA4335),
            ],
          ),
          onPressed: busy ? null : () => onSignIn('google'),
        ),
        const SizedBox(height: 8),
        _oauthButton(
          context,
          label: active == 'facebook'
              ? 'SIGNING IN…'
              : 'CONTINUE WITH FACEBOOK',
          badge: 'f',
          badgeColor: const LinearGradient(
            colors: [Color(0xFF1877F2), Color(0xFF1877F2)],
          ),
          onPressed: busy ? null : () => onSignIn('facebook'),
        ),
        const SizedBox(height: 8),
        SlantButton(
          label: active == 'phone' ? 'Signing in…' : 'Continue with phone',
          onPressed: busy ? null : () => onSignIn('phone'),
          trailing: active == 'phone'
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
      ],
    );
  }

  Widget _oauthButton(
    BuildContext context, {
    required String label,
    required String badge,
    required Gradient badgeColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: LbColors.surface,
          side: const BorderSide(color: LbColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                gradient: badgeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                badge,
                style: LbType.rankNumeral(11, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: LbType.button.copyWith(color: LbColors.textPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplianceStrip extends StatelessWidget {
  const _ComplianceStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LbColors.borderMuted)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'SKILL-BASED COMPETITION',
              style: LbType.metaSm.copyWith(fontSize: 8.5, letterSpacing: 1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('·', style: LbType.metaSm.copyWith(color: LbColors.border)),
          Flexible(
            child: Text(
              'GAB-REGULATED · COMPLIANT',
              textAlign: TextAlign.right,
              style: LbType.metaSm.copyWith(fontSize: 8.5, letterSpacing: 1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
