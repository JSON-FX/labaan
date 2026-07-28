import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/home/home_feed_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('renders greeting and live hero after data loads', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const HomeFeedScreen()));
    await pumpAndSettleForData(tester);

    // Greeting bar draws from the fixture user
    expect(find.textContaining('@tonton26'), findsOneWidget);
    expect(find.text('Ready to fight.'), findsOneWidget);

    // Live hero — Manila Clash from fixtures
    expect(find.text('Manila Clash Weekly #42'), findsOneWidget);
    expect(find.text('MATCH READY ›'), findsOneWidget);
    expect(find.text('BRACKET'), findsOneWidget);
  });

  testWidgets('shows featured, quick-actions, and trending sections', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const HomeFeedScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('// FEATURED FOR YOU'), findsOneWidget);
    expect(find.text('// QUICK ACTIONS'), findsOneWidget);
    expect(find.text('// TRENDING IN MANILA'), findsOneWidget);

    // Quick action labels
    expect(find.text('HOST'), findsOneWidget);
    expect(find.text('TEAM'), findsOneWidget);
    expect(find.text('WALLET'), findsOneWidget);
    expect(find.text('SUPPORT'), findsOneWidget);
  });
}
