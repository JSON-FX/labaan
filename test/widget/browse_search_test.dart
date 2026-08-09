import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/browse/browse_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('debounces tournament title search and can clear it', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const BrowseScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('Cavite Open Qualifier'), findsOneWidget);
    expect(find.text('Sunday Night Showdown'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('browse-search')), 'Cavite');
    await tester.pump(const Duration(milliseconds: 349));
    expect(find.text('Sunday Night Showdown'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Cavite Open Qualifier'), findsOneWidget);
    expect(find.text('Sunday Night Showdown'), findsNothing);

    await tester.tap(find.byKey(const Key('clear-browse-search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Sunday Night Showdown'), findsOneWidget);
  });

  testWidgets('shows the searched term in the empty state', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const BrowseScreen()));
    await pumpAndSettleForData(tester);

    await tester.enterText(find.byKey(const Key('browse-search')), 'NoSuchCup');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('NOTHING MATCHES'), findsOneWidget);
    expect(find.text('No open tournaments match “NoSuchCup”.'), findsOneWidget);
  });
}
