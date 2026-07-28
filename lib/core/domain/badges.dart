import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Achievement badges from spec §4.4. Awarded independently of rank; appear
/// on the player profile and add "personality beyond the rank number".
///
/// Fixed list — never invent badges without spec change.
enum AchievementBadge {
  firstBlood(
    'First Blood',
    'Win your first tournament',
    Icons.bolt_rounded,
    LbColors.danger,
  ),
  hatTrick(
    'Hat Trick',
    'Win 3 tournaments in a row',
    Icons.local_fire_department_rounded,
    LbColors.info,
  ),
  eliteSlayer(
    'Elite Slayer',
    'Beat an Elite-ranked player as a Warrior or below',
    Icons.star_rounded,
    LbColors.gold,
  ),
  communityChampion(
    'Community Champion',
    'Win 10 Community-tier tournaments',
    Icons.workspace_premium_rounded,
    LbColors.lime,
  ),
  bigGameHunter(
    'Big Game Hunter',
    'Win a Premium- or Elite-tier tournament',
    Icons.emoji_events_rounded,
    LbColors.gold,
  ),
  veteran(
    'Veteran',
    'Compete in 50+ tournaments total',
    Icons.military_tech_rounded,
    Color(0xFF4A6820),
  ),
  untouchable(
    'Untouchable',
    'Win a tournament without losing a single match (upper-bracket run)',
    Icons.shield_rounded,
    Color(0xFF88E1E9),
  );

  const AchievementBadge(this.displayName, this.trigger, this.icon, this.color);

  final String displayName;
  final String trigger;
  final IconData icon;
  final Color color;
}
