import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/domain/ranks.dart';

void main() {
  group('Rank.forWins — spec §4.1 thresholds', () {
    // Table verbatim from the spec — any change here should be a deliberate
    // product decision, not a typo.
    const table = [
      (wins: 0, expected: Rank.recruit),
      (wins: 1, expected: Rank.recruit),
      (wins: 4, expected: Rank.recruit),
      (wins: 5, expected: Rank.warrior),
      (wins: 14, expected: Rank.warrior),
      (wins: 15, expected: Rank.elite),
      (wins: 29, expected: Rank.elite),
      (wins: 30, expected: Rank.champion),
      (wins: 49, expected: Rank.champion),
      (wins: 50, expected: Rank.legend),
      (wins: 99, expected: Rank.legend),
      (wins: 100, expected: Rank.mythic),
      (wins: 199, expected: Rank.mythic),
      (wins: 200, expected: Rank.immortal),
      (wins: 999, expected: Rank.immortal),
    ];

    for (final row in table) {
      test('${row.wins} wins → ${row.expected.displayName}', () {
        expect(Rank.forWins(row.wins), row.expected);
      });
    }
  });

  group('winsToNext', () {
    test('Champion with 36 wins → 14 to Legend', () {
      expect(Rank.champion.winsToNext(36), 14);
    });

    test('Warrior with exactly minWins → span-1 to Elite', () {
      // Warrior 5–14, Elite starts at 15, so at 5 wins you need 10 more.
      expect(Rank.warrior.winsToNext(5), 10);
    });

    test('Immortal → 0 (already at max)', () {
      expect(Rank.immortal.winsToNext(200), 0);
      expect(Rank.immortal.winsToNext(500), 0);
    });
  });

  group('progressWithin', () {
    test('bottom of tier → 0', () {
      expect(Rank.champion.progressWithin(30), closeTo(0.05, 0.1));
    });

    test('top of tier → ~1', () {
      // Champion span is 30..49 = 20 slots wide, so (49 - 30) / 20 = 0.95.
      // Full 1.0 is only hit exactly at the promotion threshold.
      expect(Rank.champion.progressWithin(49), closeTo(0.95, 0.05));
    });

    test('clamps below tier to 0', () {
      expect(Rank.champion.progressWithin(0), 0.0);
    });

    test('clamps above tier to 1', () {
      expect(Rank.champion.progressWithin(9999), 1.0);
    });
  });

  group('next', () {
    test('Champion.next → Legend', () {
      expect(Rank.champion.next, Rank.legend);
    });

    test('Immortal.next → null', () {
      expect(Rank.immortal.next, isNull);
    });
  });

  test('metalName snapshot matches spec §4.1', () {
    expect(Rank.recruit.metalName, 'Bronze');
    expect(Rank.warrior.metalName, 'Iron / Steel');
    expect(Rank.elite.metalName, 'Silver');
    expect(Rank.champion.metalName, 'Gold');
    expect(Rank.legend.metalName, 'Platinum');
    expect(Rank.mythic.metalName, 'Diamond');
    expect(Rank.immortal.metalName, 'Red / Black');
  });
}
