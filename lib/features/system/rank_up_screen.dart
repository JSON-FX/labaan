import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/badges.dart';
import '../../core/domain/ranks.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/rank_hex.dart';
import '../../core/widgets/slant_button.dart';

/// System · 3A · Rank-Up Moment.
///
/// The celebratory takeover: pulsing hex, tier name, unlocked-with-this-win
/// badge shelf, and share / view-profile CTAs.
class RankUpScreen extends StatefulWidget {
  const RankUpScreen({super.key});

  @override
  State<RankUpScreen> createState() => _RankUpScreenState();
}

class _RankUpScreenState extends State<RankUpScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBurst(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              child: Column(
                children: [
                  Text(
                    'RANK · UP',
                    style: LbType.metaLabel.copyWith(
                      color: LbColors.lime,
                      fontSize: 11,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (context, _) => Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: LbColors.lime.withValues(
                              alpha: 0.55 + 0.25 * _glow.value,
                            ),
                            blurRadius: 40 + 20 * _glow.value,
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                      child: RankHex(
                        rank: Rank.elite.level,
                        size: 170,
                        color: rankAccent(Rank.elite),
                        textColor: LbColors.textPrimaryHi,
                        numeralScale: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    Rank.elite.displayName.toUpperCase(),
                    style: LbType.takeoverTitle,
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: LbType.metaSm.copyWith(
                        fontSize: 10,
                        letterSpacing: 3,
                        color: LbColors.textMuted,
                      ),
                      children: [
                        TextSpan(text: Rank.warrior.displayName.toUpperCase()),
                        TextSpan(
                          text: ' → ${Rank.elite.displayName.toUpperCase()}',
                          style: LbType.metaSm.copyWith(
                            color: LbColors.lime,
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text:
                              '  ·  RANK ${Rank.elite.level}  ·  ${Rank.elite.metalName.toUpperCase()}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _UnlockedShelf(),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: SlantButton(
                      label: 'Share rank-up',
                      onPressed: () {},
                      leading: const Icon(
                        Icons.ios_share_rounded,
                        size: 16,
                        color: LbColors.limeInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: GhostButton(
                      label: 'View profile',
                      onPressed: () => context.go('/profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBurst extends StatelessWidget {
  const _AmbientBurst();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 0.9,
              colors: [
                LbColors.lime.withValues(alpha: 0.18),
                Colors.transparent,
              ],
              stops: const [0, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockedShelf extends StatelessWidget {
  const _UnlockedShelf();

  /// Badges unlocked *this* tournament win. Names come from the spec §4.4
  /// fixed set — never inject decorative-only labels here.
  static const _badges = <AchievementBadge>[
    AchievementBadge.eliteSlayer,
    AchievementBadge.hatTrick,
    AchievementBadge.firstBlood,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LbColors.surface.withValues(alpha: 0.7),
        border: Border.all(color: LbColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'UNLOCKED WITH THIS WIN',
            style: LbType.metaSm.copyWith(
              color: LbColors.textDim,
              fontSize: 9.5,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _badges.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _badges[i].color.withValues(alpha: 0.4),
                              _badges[i].color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          _badges[i].icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _badges[i].displayName.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LbType.metaSm.copyWith(
                          color: LbColors.textSecondary,
                          fontSize: 8.5,
                          letterSpacing: 0.5,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'WIN ${Rank.elite.minWins} · QC Grind Series #07',
            style: LbType.metaSm.copyWith(
              color: LbColors.textMuted,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}
