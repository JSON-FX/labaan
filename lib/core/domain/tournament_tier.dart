import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../widgets/lb_chip.dart';

/// Tournament tiers from spec §6.3. All values are Super-Admin-configurable
/// at runtime via the `fee_config` table — this enum is a compile-time
/// snapshot for defaults and static UI. Amounts in PHP.
enum TournamentTier {
  community('Community', 50, 0.08),
  standard('Standard', 100, 0.10),
  premium('Premium', 250, 0.15),
  elite('Elite', 500, 0.15);

  const TournamentTier(this.displayName, this.entryFeePhp, this.commissionRate);

  final String displayName;
  final int entryFeePhp;
  final double commissionRate;

  /// PayMongo gateway fee, ~3.5% of the entry fee.
  double get gatewayFeePhp => entryFeePhp * 0.035;
  double get commissionPhp => entryFeePhp * commissionRate;
  double get prizeContributionPhp =>
      entryFeePhp - commissionPhp - gatewayFeePhp;

  LbChipTone get chipTone => switch (this) {
    TournamentTier.community => LbChipTone.neutral,
    TournamentTier.standard => LbChipTone.neutral,
    TournamentTier.premium => LbChipTone.gold,
    TournamentTier.elite => LbChipTone.lime,
  };

  Color get accent => switch (this) {
    TournamentTier.community => LbColors.textMuted,
    TournamentTier.standard => LbColors.info,
    TournamentTier.premium => LbColors.gold,
    TournamentTier.elite => LbColors.lime,
  };
}

/// Format prize numbers as `₱1,234.50`. Small helper — no intl dep at MVP.
String formatPeso(num php, {int decimals = 2}) {
  final s = php.toStringAsFixed(decimals);
  final parts = s.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return decimals == 0 ? '₱$buf' : '₱$buf.${parts[1]}';
}
