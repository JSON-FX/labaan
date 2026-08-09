import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/system/host_tournament_screen.dart';
import 'package:labaan/features/system/support_screen.dart';

import '_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('ChakraPetch', const ['assets/fonts/ChakraPetch-Bold.ttf']);
    await _loadFont('IBMPlexSans', const [
      'assets/fonts/IBMPlexSans-Regular.ttf',
      'assets/fonts/IBMPlexSans-Medium.ttf',
      'assets/fonts/IBMPlexSans-SemiBold.ttf',
      'assets/fonts/IBMPlexSans-Bold.ttf',
    ]);
    await _loadFont('IBMPlexMono', const [
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
      'assets/fonts/IBMPlexMono-Bold.ttf',
    ]);
  });

  testWidgets('Host destination matches its golden', (tester) async {
    setPhoneViewport(tester);
    const boundaryKey = Key('host-golden');

    await tester.pumpWidget(
      hostScreen(
        const RepaintBoundary(key: boundaryKey, child: HostTournamentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('../goldens/host_destination.png'),
    );
  });

  testWidgets('Support destination matches its golden', (tester) async {
    setPhoneViewport(tester);
    const boundaryKey = Key('support-golden');

    await tester.pumpWidget(
      hostScreen(
        const RepaintBoundary(
          key: boundaryKey,
          child: SupportScreen(topic: 'organizer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('../goldens/support_destination.png'),
    );
  });
}

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}
