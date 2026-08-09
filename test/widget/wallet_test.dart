import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/system/wallet_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('wallet summarizes cash flow and lists tournament activity', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1200);
    await tester.pumpWidget(hostRoute(const WalletScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('-₱466.00'), findsOneWidget);
    expect(find.text('₱184.00'), findsOneWidget);
    expect(find.text('₱650.00'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('// TRANSACTION HISTORY'), 300);
    await tester.pump();
    expect(find.text('// TRANSACTION HISTORY'), findsOneWidget);
    expect(find.text('Manila Clash #42'), findsOneWidget);
    expect(find.text('All-Stars Season 3'), findsOneWidget);
    expect(find.text('QC Grind #07'), findsNWidgets(2));
    expect(find.textContaining('not a stored balance'), findsOneWidget);
  });

  testWidgets('wallet can filter transaction history to prizes', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1200);
    await tester.pumpWidget(hostRoute(const WalletScreen()));
    await pumpAndSettleForData(tester);

    await tester.tap(find.text('Prizes'));
    await tester.pump();

    expect(find.text('PRIZE PAYOUT · GCASH · COMPLETED'), findsOneWidget);
    expect(find.text('ENTRY FEE · MAYA · PAID'), findsNothing);
  });
}
