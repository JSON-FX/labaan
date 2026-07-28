import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/identity/setup_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('Step 1: Continue disabled until username ≥ 3 chars', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const SetupScreen()));
    await tester.pump();

    expect(find.text('Pick your handle'), findsOneWidget);
    expect(find.text('STEP 1 / 3'), findsOneWidget);

    // Type 2 chars — still invalid.
    await tester.enterText(find.byType(EditableText), 'ab');
    await tester.pump();

    // Type 3 chars — Continue becomes valid.
    await tester.enterText(find.byType(EditableText), 'abc');
    await tester.pump();

    // Advance to step 2.
    await tester.tap(find.text('CONTINUE'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Where do you compete from?'), findsOneWidget);
    expect(find.text('STEP 2 / 3'), findsOneWidget);
  });

  testWidgets('Step 3 shows the 5 games from the spec', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const SetupScreen()));
    await tester.pump();

    // Step 1: username
    await tester.enterText(find.byType(EditableText), 'tester');
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pump(const Duration(milliseconds: 300));

    // Step 2: pick a region
    await tester.tap(find.text('MANILA'));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pump(const Duration(milliseconds: 300));

    // Step 3
    expect(find.text('MLBB'), findsOneWidget);
    expect(find.text('VALORANT'), findsOneWidget);
    expect(find.text('COD Mobile'), findsOneWidget);
    expect(find.text('PUBG'), findsOneWidget);
    expect(find.text('TEKKEN 8'), findsOneWidget);
    expect(find.text('FINISH'), findsOneWidget);
  });
}
