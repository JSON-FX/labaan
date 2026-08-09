import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/data/fixtures.dart';
import 'package:labaan/core/data/models.dart';
import 'package:labaan/core/domain/ranks.dart';
import 'package:labaan/core/domain/tournament_status.dart';

void main() {
  group('LbUser.copyWith', () {
    test('preserves id/email and overrides given fields', () {
      final base = LbFixtures.me;
      final updated = base.copyWith(
        username: '@newhandle',
        region: 'Cebu',
        games: const ['MLBB'],
        hasCompletedSetup: false,
      );
      expect(updated.id, base.id);
      expect(updated.email, base.email);
      expect(updated.username, '@newhandle');
      expect(updated.region, 'Cebu');
      expect(updated.games, const ['MLBB']);
      expect(updated.hasCompletedSetup, false);
    });

    test('omitted fields stay unchanged', () {
      final base = LbFixtures.me;
      final copy = base.copyWith(username: 'x');
      expect(copy.region, base.region);
      expect(copy.games, base.games);
      expect(copy.hasCompletedSetup, base.hasCompletedSetup);
    });
  });

  group('LbUserRank derived helpers', () {
    test('winsToNext threads through Rank', () {
      final champ = LbUserRank(
        userId: 'u',
        totalWins: 36,
        rank: Rank.champion,
        rankUpdatedAt: DateTime(2026, 1, 1),
      );
      expect(champ.winsToNext, 14);
    });

    test('progressWithinRank threads through Rank', () {
      final champ = LbUserRank(
        userId: 'u',
        totalWins: 30,
        rank: Rank.champion,
        rankUpdatedAt: DateTime(2026, 1, 1),
      );
      expect(champ.progressWithinRank, closeTo(0.05, 0.1));
    });
  });

  group('LbTournament derived state', () {
    test('slotsRemaining = max − registered', () {
      expect(LbFixtures.manilaAscentS3.slotsRemaining, 2);
      expect(LbFixtures.qcGrind08.slotsRemaining, 32);
    });

    test('isLive iff status == live', () {
      expect(LbFixtures.liveManilaClash.isLive, true);
      expect(LbFixtures.manilaAscentS3.isLive, false);
    });

    test('isOpen for Open or FillingUp', () {
      expect(LbFixtures.manilaAscentS3.isOpen, true); // fillingUp
      expect(LbFixtures.sundayNight.isOpen, true); // open
      expect(LbFixtures.liveManilaClash.isOpen, false); // live
      expect(LbFixtures.qcGrind07Completed.isOpen, false); // completed
    });

    test('countdownToLock returns null after locksAt has passed', () {
      final future = LbFixtures.now.add(const Duration(days: 30));
      expect(LbFixtures.manilaAscentS3.countdownToLock(future), isNull);
    });

    test('countdownToLock positive Duration before lockAt', () {
      final d = LbFixtures.manilaAscentS3.countdownToLock(LbFixtures.now);
      expect(d, isNotNull);
      expect(d!.isNegative, false);
    });

    test('Wallet tournament exposes its published reward rule', () {
      final tournament = LbFixtures.caviteOpen;
      expect(tournament.hasRewardRule, isTrue);
      expect(tournament.rewardPoolIsLocked, isFalse);
      expect(tournament.rewardCompetitorBasis, RewardCompetitorBasis.team);
      expect(tournament.rewardPointsPerCompetitor, 100);
      expect(
        (tournament.rewardFirstPlaceBps ?? 0) +
            (tournament.rewardSecondPlaceBps ?? 0) +
            (tournament.rewardThirdPlaceBps ?? 0),
        10000,
      );
    });
  });

  test('BracketFormat.displayName spec table', () {
    expect(BracketFormat.doubleElimination.displayName, 'Double elimination');
    expect(BracketFormat.singleElimination.displayName, 'Single elimination');
    expect(BracketFormat.roundRobin.displayName, 'Round robin');
  });
}
