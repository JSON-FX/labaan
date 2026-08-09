import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/system/notifications_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('renders Today and Earlier groups with fixture items', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const NotificationsScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('// TODAY'), findsOneWidget);
    expect(find.text('// EARLIER'), findsOneWidget);

    // A time-sensitive + a celebration item live in Today
    expect(find.text('Match ready'), findsOneWidget);
    expect(find.text('Victory Points earned'), findsOneWidget);
    expect(find.textContaining('18 Victory Points'), findsOneWidget);
    expect(find.textContaining('GCash'), findsNothing);

    // Team-invite gets inline Accept/Decline
    expect(find.text('ACCEPT'), findsOneWidget);
    expect(find.text('DECLINE'), findsOneWidget);
  });

  testWidgets('dispute notification shows body and lives in Today', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const NotificationsScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('Dispute opened'), findsOneWidget);
    expect(find.textContaining('15m'), findsWidgets);
  });

  testWidgets('accepting a team invite resolves its inline actions', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const NotificationsScreen()));
    await pumpAndSettleForData(tester);

    await tester.tap(find.text('ACCEPT'));
    await tester.pump();

    expect(find.text('INVITATION ACCEPTED'), findsOneWidget);
    expect(find.text('DECLINE'), findsNothing);
  });

  testWidgets('declining a team invite resolves its inline actions', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const NotificationsScreen()));
    await pumpAndSettleForData(tester);

    await tester.tap(find.text('DECLINE'));
    await tester.pump();

    expect(find.text('INVITATION DECLINED'), findsOneWidget);
    expect(find.text('ACCEPT'), findsNothing);
  });
}
