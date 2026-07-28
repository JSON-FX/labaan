import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// The 7-rank ladder from spec §4.1. Rank is based on cumulative tournament
/// wins across all games/tiers. Rank never decreases in MVP.
///
/// Thresholds are stored in `rank_config` at runtime and are Super-Admin
/// configurable — this enum is a compile-time snapshot for UI defaults.
enum Rank {
  recruit(1, 'Recruit', 0, 4, Color(0xFFCD7F32)),
  warrior(2, 'Warrior', 5, 14, Color(0xFF8B95A1)),
  elite(3, 'Elite', 15, 29, Color(0xFFC0C0C0)),
  champion(4, 'Champion', 30, 49, Color(0xFFD4AF37)),
  legend(5, 'Legend', 50, 99, Color(0xFFE5E4E2)),
  mythic(6, 'Mythic', 100, 199, Color(0xFF88E1E9)),
  immortal(7, 'Immortal', 200, 1 << 30, Color(0xFFE43F5A));

  const Rank(
    this.level,
    this.displayName,
    this.minWins,
    this.maxWins,
    this.badgeColor,
  );

  final int level;
  final String displayName;
  final int minWins;
  final int maxWins;
  final Color badgeColor;

  /// Metal / crystal color as printed on the spec table — "Bronze", "Silver".
  String get metalName => switch (this) {
    Rank.recruit => 'Bronze',
    Rank.warrior => 'Iron / Steel',
    Rank.elite => 'Silver',
    Rank.champion => 'Gold',
    Rank.legend => 'Platinum',
    Rank.mythic => 'Diamond',
    Rank.immortal => 'Red / Black',
  };

  static Rank forWins(int wins) {
    for (final r in values) {
      if (wins >= r.minWins && wins <= r.maxWins) return r;
    }
    return Rank.immortal;
  }

  Rank? get next => level < values.length ? values[level] : null;

  /// Wins remaining to reach the next tier. Returns 0 for Immortal.
  int winsToNext(int wins) {
    final n = next;
    if (n == null) return 0;
    return (n.minWins - wins).clamp(0, 1 << 30);
  }

  /// 0.0 → just entered tier, 1.0 → about to promote.
  double progressWithin(int wins) {
    final span = maxWins - minWins + 1;
    if (span <= 0) return 1.0;
    return ((wins - minWins) / span).clamp(0.0, 1.0);
  }
}

/// Accent color for the rank badge on-screen. Champion/Legend/Immortal pull
/// from the metal palette; the rest fall back to the lime primary.
Color rankAccent(Rank r) => switch (r) {
  Rank.champion || Rank.legend || Rank.mythic || Rank.immortal => r.badgeColor,
  _ => LbColors.lime,
};
