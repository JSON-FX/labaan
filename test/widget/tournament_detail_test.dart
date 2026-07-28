import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/data/fixtures.dart';
import 'package:labaan/features/tournament/tournament_detail_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('never exposes organizer database ids', (tester) async {
    setPhoneViewport(tester);
    final tournament = LbFixtures.caviteOpen;
    await tester.pumpWidget(
      hostRoute(TournamentDetailScreen(slug: tournament.id)),
    );
    await pumpAndSettleForData(tester);

    expect(find.text(tournament.organizerId), findsNothing);
    expect(find.text('Tournament organizer'), findsOneWidget);
  });
}
