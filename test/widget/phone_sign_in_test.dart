import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/identity/phone_sign_in_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('requests and verifies a six-digit phone OTP', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const PhoneSignInScreen()));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'Phone number'),
      '+639171234567',
    );
    await tester.pump();
    await tester.tap(find.text('SEND CODE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('We sent a 6-digit code'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Verification code'),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.text('VERIFY CODE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
