import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/identity/profile_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('renders team name and tag instead of its database id', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const ProfileScreen()));
    await pumpAndSettleForData(tester);

    await tester.ensureVisible(find.text('Team MNL'));
    await tester.pump();

    expect(find.text('Team MNL'), findsOneWidget);
    expect(find.text('MNL'), findsOneWidget);
    expect(find.text('t_mnl'), findsNothing);
  });
}
