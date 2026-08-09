import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/compete/result_verification_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('shows submitted score, evidence, and opponent decision', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const ResultVerificationScreen(matchId: 'm_u3')),
    );
    await pumpAndSettleForData(tester);

    expect(find.text('Review Result'), findsOneWidget);
    expect(find.text('Team MNL'), findsOneWidget);
    expect(find.text('Davao GG'), findsOneWidget);
    expect(find.text('SCREENSHOT ATTACHED'), findsOneWidget);
    expect(
      find.text('I confirm this final score is accurate.'),
      findsOneWidget,
    );
    expect(find.text('CONFIRM RESULT'), findsOneWidget);
    expect(find.text('OPEN DISPUTE'), findsOneWidget);
  });

  testWidgets('requires attestation before confirming the result', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const ResultVerificationScreen(matchId: 'm_u3')),
    );
    await pumpAndSettleForData(tester);

    await tester.tap(find.text('CONFIRM RESULT'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Review Result'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
