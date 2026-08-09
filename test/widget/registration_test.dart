import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/data/fixtures.dart';
import 'package:labaan/core/data/mock_repos.dart';
import 'package:labaan/core/data/models.dart';
import 'package:labaan/features/registration/registration_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('Wallet tournament shows Credit balance, cost, and result', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1000);
    await tester.pumpWidget(
      hostRoute(RegistrationScreen(tournamentId: LbFixtures.caviteOpen.id)),
    );
    await pumpAndSettleForData(tester);

    expect(find.text('// PAY WITH CREDITS'), findsOneWidget);
    expect(find.text('1,000 CR'), findsOneWidget);
    expect(find.text('-250 CR'), findsOneWidget);
    expect(find.text('750 CR'), findsOneWidget);
    expect(find.text('USE CREDITS & ENTER'), findsOneWidget);
    expect(find.text('// PAYMENT METHOD'), findsNothing);
    expect(find.textContaining('PAYMONGO TEST MODE'), findsNothing);
  });

  testWidgets(
    'Wallet tournament disables entry when Credits are insufficient',
    (tester) async {
      setPhoneViewport(tester, height: 1000);
      final state = MockWalletState()..entryCreditBalance = 100;
      await tester.pumpWidget(
        hostRoute(
          RegistrationScreen(tournamentId: LbFixtures.caviteOpen.id),
          registrationRepo: MockRegistrationRepo(state),
          walletRepo: MockWalletRepo(state),
        ),
      );
      await pumpAndSettleForData(tester);

      expect(
        find.text('INSUFFICIENT CREDITS · 150 CR more needed'),
        findsOneWidget,
      );
      expect(find.textContaining('150 CR more needed'), findsOneWidget);
      expect(find.text('INSUFFICIENT CREDITS'), findsOneWidget);
    },
  );

  testWidgets('legacy tournament retains the PayMongo payment path', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1100);
    await tester.pumpWidget(
      hostRoute(RegistrationScreen(tournamentId: LbFixtures.sundayNight.id)),
    );
    await pumpAndSettleForData(tester);
    await tester.scrollUntilVisible(
      find.textContaining('PAYMONGO TEST MODE'),
      200,
    );

    expect(find.text('// PAYMENT METHOD'), findsOneWidget);
    expect(find.textContaining('GCash succeeds'), findsOneWidget);
  });

  test('mock Credit entry and cancellation update the shared ledger', () async {
    final state = MockWalletState();
    final registrations = MockRegistrationRepo(state);

    final entered = await registrations.enterWithCredits(
      tournamentId: LbFixtures.caviteOpen.id,
      userId: LbFixtures.me.id,
      idempotencyKey: 'mock-credit-entry-1',
    );
    expect(entered.registration.paymentStatus, RegistrationPaymentStatus.paid);
    expect(entered.entryCreditBalance, 750);
    expect(state.transactions.first.kind, LbWalletTransactionKind.entryFee);

    final cancelled = await registrations.cancelCreditRegistration(
      registrationId: entered.registration.id,
      userId: LbFixtures.me.id,
      idempotencyKey: 'mock-credit-refund-1',
    );
    expect(
      cancelled.registration.paymentStatus,
      RegistrationPaymentStatus.refunded,
    );
    expect(cancelled.entryCreditBalance, 1000);
    expect(state.transactions.first.kind, LbWalletTransactionKind.entryRefund);
  });
}
