import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/system/host_tournament_screen.dart';
import 'package:labaan/features/system/support_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('Host exposes organizer boundaries and opens the GAB registry', (
    tester,
  ) async {
    setPhoneViewport(tester);
    Uri? openedUri;
    await tester.pumpWidget(
      hostRoute(
        HostTournamentScreen(
          externalLauncher: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );

    expect(find.text('Host on Labaan'), findsOneWidget);
    expect(find.text('// ORGANIZER ONBOARDING'), findsOneWidget);
    await tester.tap(find.text('GAB REGISTRY'));
    await tester.pump();
    expect(openedUri, Uri.parse('https://gab.gov.ph/'));
  });

  testWidgets('organizer support context is explicit', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const SupportScreen(topic: 'organizer')));

    expect(find.text('Organizer access'), findsOneWidget);
    expect(find.text('Connected accounts'), findsOneWidget);
    expect(find.text('Competition issues'), findsOneWidget);
    expect(find.text('Privacy & account data'), findsOneWidget);
  });
}
