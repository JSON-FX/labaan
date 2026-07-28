import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/leaderboard/leaderboard_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('Players tab shows fixture leaderboard with YOU chip', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const LeaderboardScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('@thewarden'), findsOneWidget);
    expect(find.text('@tonton26'), findsOneWidget);
    // "YOU" chip is the highlight for the current user's row.
    expect(find.text('YOU'), findsOneWidget);
  });

  testWidgets('toggling to Teams swaps the board', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const LeaderboardScreen()));
    await pumpAndSettleForData(tester);

    await tester.tap(find.text('Teams'));
    await pumpAndSettleForData(tester);

    expect(find.text('Team MNL'), findsOneWidget);
    expect(find.text('Cebu Kings'), findsOneWidget);
    expect(find.text('Davao GG'), findsOneWidget);
  });
}
