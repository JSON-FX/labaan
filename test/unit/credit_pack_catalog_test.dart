import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/data/mock_repos.dart';
import 'package:labaan/core/data/models.dart';

void main() {
  group('Credit pack catalog', () {
    test('returns server-shaped PayMongo packs for direct Android', () async {
      final packs = await MockWalletRepo().activeCreditPacks(
        provider: CreditPackProvider.paymongo,
        platform: CreditPackPlatform.androidDirect,
      );

      expect(packs.map((pack) => pack.packCode), [
        'dev_credit_50',
        'dev_credit_100',
        'dev_credit_250',
      ]);
      expect(packs.map((pack) => pack.creditAmount), [50, 100, 250]);
      expect(packs.map((pack) => pack.priceCentavos), [5000, 10000, 25000]);
      expect(packs.every((pack) => pack.currencyCode == 'PHP'), isTrue);
      expect(packs.every((pack) => pack.maxPurchasesPerDay == 10), isTrue);
    });

    test('keeps provider/platform catalogs isolated', () async {
      final applePacks = await MockWalletRepo().activeCreditPacks(
        provider: CreditPackProvider.appleIap,
        platform: CreditPackPlatform.ios,
      );

      expect(applePacks, isEmpty);
    });

    test('derives a display-only peso amount from centavos', () {
      const pack = LbCreditPack(
        id: 'pack',
        packCode: 'credit_pack',
        revision: 1,
        provider: CreditPackProvider.paymongo,
        platform: CreditPackPlatform.web,
        creditAmount: 75,
        priceCentavos: 7999,
        currencyCode: 'PHP',
        maxPurchasesPerDay: 3,
        sortOrder: 1,
      );

      expect(pack.pricePhp, 79.99);
    });
  });
}
