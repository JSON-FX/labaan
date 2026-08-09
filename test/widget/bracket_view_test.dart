import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/tournament/bracket_view_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('renders bracket rails with real team tags', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const BracketViewScreen(tournamentId: 'tr_live')),
    );
    await pumpAndSettleForData(tester);

    expect(find.text('// UPPER BRACKET'), findsOneWidget);
    expect(find.text('// LOWER BRACKET'), findsOneWidget);
    expect(find.text('// GRAND FINAL'), findsOneWidget);
    expect(find.text('MNL'), findsWidgets);
    expect(find.text('DVO'), findsWidgets);
    expect(find.text('LIVE · SUBSCRIBED'), findsOneWidget);
  });
}
