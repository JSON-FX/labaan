import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/system/wallet_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('wallet shows dual balances and safe ledger activity', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1200);
    await tester.pumpWidget(hostRoute(const WalletScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('1,000 CR'), findsOneWidget);
    expect(find.text('250 VP'), findsOneWidget);
    expect(find.text('CREDITS'), findsOneWidget);
    expect(find.text('VICTORY POINTS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('// TRANSACTION HISTORY'), 300);
    await tester.pump();
    expect(find.text('// TRANSACTION HISTORY'), findsOneWidget);
    expect(find.text('BALANCE ADJUSTMENT'), findsNWidgets(2));
    expect(find.text('+1,000 CR'), findsOneWidget);
    expect(find.text('+250 VP'), findsOneWidget);
    expect(find.textContaining('Neither balance is cash'), findsOneWidget);
    expect(find.text('Payout destination'), findsNothing);
  });

  testWidgets('wallet can filter transaction history by currency', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1200);
    await tester.pumpWidget(hostRoute(const WalletScreen()));
    await pumpAndSettleForData(tester);

    await tester.tap(find.text('Rewards'));
    await tester.pump();

    expect(find.text('+250 VP'), findsOneWidget);
    expect(find.text('+1,000 CR'), findsNothing);
  });
}
