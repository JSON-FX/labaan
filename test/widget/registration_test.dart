import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/data/fixtures.dart';
import 'package:labaan/core/data/mock_repos.dart';
import 'package:labaan/core/data/models.dart';
import 'package:labaan/features/registration/registration_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('shows the explicit PayMongo mock outcome contract', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(RegistrationScreen(tournamentId: LbFixtures.caviteOpen.id)),
    );
    await pumpAndSettleForData(tester);
    await tester.scrollUntilVisible(
      find.textContaining('PAYMONGO TEST MODE'),
      200,
    );

    expect(find.textContaining('GCash succeeds'), findsOneWidget);
    expect(find.textContaining('Maya stays pending'), findsOneWidget);
    expect(find.textContaining('Card declines'), findsOneWidget);
  });

  test('mock repository exposes paid, pending, and failed outcomes', () async {
    final repo = MockRegistrationRepo();

    Future<RegistrationPaymentStatus> status(PayMethod method) async {
      final checkout = await repo.register(
        tournamentId: LbFixtures.caviteOpen.id,
        userId: LbFixtures.me.id,
        method: method,
        captchaToken: 'test',
      );
      return checkout.registration.paymentStatus;
    }

    expect(await status(PayMethod.gcash), RegistrationPaymentStatus.paid);
    expect(await status(PayMethod.maya), RegistrationPaymentStatus.pending);
    expect(await status(PayMethod.card), RegistrationPaymentStatus.failed);
  });
}
