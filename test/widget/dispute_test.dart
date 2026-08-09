import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/compete/dispute_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('lists all 6 reasons and shows the 15m SLA pill', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const DisputeScreen(matchId: 'm_u3')));
    await pumpAndSettleForData(tester);

    expect(find.text('Score is wrong'), findsOneWidget);
    expect(find.text('Opponent no-show'), findsOneWidget);
    expect(find.text('Cheating suspected'), findsOneWidget);
    expect(find.text('Technical issue'), findsOneWidget);
    expect(find.text('Rule violation'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    expect(find.text('15M SLA'), findsOneWidget);
    expect(find.textContaining('Team MNL'), findsOneWidget);
    expect(find.textContaining('Davao GG'), findsOneWidget);
  });

  testWidgets('Open dispute stays disabled without both reason and detail', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const DisputeScreen(matchId: 'm_u3')));
    await pumpAndSettleForData(tester);

    // Neither reason nor detail — tapping the CTA is a no-op; screen stays
    // on the dispute form (no dialog appears).
    await tester.tap(find.text('OPEN DISPUTE'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Dispute submitted'), findsNothing);

    // Pick a reason.
    await tester.tap(find.text('Cheating suspected'));
    await tester.pump();

    // Type a short (< 20 char) detail — still disabled.
    await tester.enterText(find.byType(EditableText).first, 'too short');
    await tester.pump();
    await tester.tap(find.text('OPEN DISPUTE'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Dispute submitted'), findsNothing);

    // Type a valid (≥ 20 char) detail — CTA becomes real.
    await tester.enterText(
      find.byType(EditableText).first,
      'This description is definitely long enough now for real',
    );
    await tester.pump();
    await tester.tap(find.text('OPEN DISPUTE'));
    // Wait for mock write latency (~520 ms).
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Dispute submitted'), findsOneWidget);
  });
}
