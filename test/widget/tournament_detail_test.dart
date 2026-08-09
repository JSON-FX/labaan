import 'package:flutter/material.dart';
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

  testWidgets('shares the loaded tournament from the app bar', (tester) async {
    setPhoneViewport(tester);
    final tournament = LbFixtures.caviteOpen;
    String? sharedId;
    await tester.pumpWidget(
      hostRoute(
        TournamentDetailScreen(
          slug: tournament.id,
          shareTournament: (value, _) async => sharedId = value.id,
        ),
      ),
    );
    await pumpAndSettleForData(tester);

    await tester.tap(find.byKey(const Key('share-tournament')));
    await tester.pump();

    expect(sharedId, tournament.id);
  });

  testWidgets('shows the published Victory Point reward formula', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1100);
    final tournament = LbFixtures.caviteOpen;
    await tester.pumpWidget(
      hostRoute(TournamentDetailScreen(slug: tournament.id)),
    );
    await pumpAndSettleForData(tester);

    expect(find.text('100 VP/TEAM'), findsOneWidget);
    expect(find.text('PUBLISHED REWARD RULE'), findsOneWidget);
    expect(
      find.textContaining('Adds 100 VP per confirmed team'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Cap 1600 VP · 1st 70% · 2nd 30%'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Starts with 4 confirmed teams · below minimum: full Credit refund',
      ),
      findsOneWidget,
    );
  });
}
