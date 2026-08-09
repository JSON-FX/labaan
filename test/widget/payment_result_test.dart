import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/registration/payment_result_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('success variant: title, receipt, and both actions', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const PaymentResultScreen(status: PaymentResult.success)),
    );
    await tester.pump();

    expect(find.text("You're in."), findsOneWidget);
    expect(find.text('PAID · SLOT RESERVED'), findsOneWidget);
    expect(find.text('VIEW BRACKET'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('pending variant: shows only Back-to-home', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const PaymentResultScreen(status: PaymentResult.pending)),
    );
    await tester.pump();

    expect(find.text('Processing payment'), findsOneWidget);
    expect(find.text('AWAITING SETTLEMENT'), findsOneWidget);
    expect(find.text('BACK TO HOME'), findsOneWidget);
    expect(find.text('VIEW BRACKET'), findsNothing);
  });

  testWidgets('failed variant: shows retry CTA', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const PaymentResultScreen(status: PaymentResult.failed)),
    );
    await tester.pump();

    expect(find.text('Payment failed'), findsOneWidget);
    expect(find.text('NOT CHARGED'), findsOneWidget);
    expect(find.text('RETRY PAYMENT'), findsOneWidget);
  });

  testWidgets('pending return refreshes to paid from the backend stream', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(
        const PaymentResultScreen(
          status: PaymentResult.pending,
          registrationId: '123e4567-e89b-42d3-a456-426614174000',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Processing payment'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text("You're in."), findsOneWidget);
    expect(find.text('PAID · SLOT RESERVED'), findsOneWidget);
  });
}
