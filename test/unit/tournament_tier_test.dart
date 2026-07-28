import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/domain/tournament_tier.dart';

void main() {
  group('TournamentTier — spec §6.3 fee table', () {
    test('Community: ₱50 · 8% · net ₱46', () {
      expect(TournamentTier.community.entryFeePhp, 50);
      expect(TournamentTier.community.commissionRate, 0.08);
      expect(TournamentTier.community.commissionPhp, closeTo(4.0, 0.01));
      expect(
        TournamentTier.community.prizeContributionPhp,
        closeTo(50 - 4 - 1.75, 0.01),
      );
    });

    test('Standard: ₱100 · 10%', () {
      expect(TournamentTier.standard.entryFeePhp, 100);
      expect(TournamentTier.standard.commissionRate, 0.10);
      expect(TournamentTier.standard.commissionPhp, closeTo(10.0, 0.01));
    });

    test('Premium: ₱250 · 15%', () {
      expect(TournamentTier.premium.entryFeePhp, 250);
      expect(TournamentTier.premium.commissionRate, 0.15);
      expect(TournamentTier.premium.commissionPhp, closeTo(37.5, 0.01));
    });

    test('Elite: ₱500 · 15% · net ₱425 (matches HiFi Registration screen)', () {
      expect(TournamentTier.elite.entryFeePhp, 500);
      expect(TournamentTier.elite.commissionRate, 0.15);
      expect(TournamentTier.elite.commissionPhp, closeTo(75.0, 0.01));
      // Registration HiFi shows ₱425 to prize pool → 500 - 75 - 17.5.
      expect(TournamentTier.elite.prizeContributionPhp, closeTo(407.5, 0.01));
    });

    test('gateway fee is ~3.5% of entry across all tiers', () {
      for (final tier in TournamentTier.values) {
        expect(tier.gatewayFeePhp, closeTo(tier.entryFeePhp * 0.035, 0.01));
      }
    });
  });

  group('formatPeso', () {
    test('formats with 2 decimals + commas', () {
      expect(formatPeso(500), '₱500.00');
      expect(formatPeso(1234.5), '₱1,234.50');
      expect(formatPeso(1000000), '₱1,000,000.00');
    });

    test('zero decimals renders no decimal point', () {
      expect(formatPeso(500, decimals: 0), '₱500');
      expect(formatPeso(5250, decimals: 0), '₱5,250');
    });
  });
}
