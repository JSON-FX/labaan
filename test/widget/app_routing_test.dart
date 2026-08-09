import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/app.dart';

import '_helpers.dart';

void main() {
  testWidgets('root platform callback redirects to onboarding', (tester) async {
    setPhoneViewport(tester);
    final router = LabaanApp.createRouter(initialLocation: '/');
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(child: LabaanApp(router: router)));
    await pumpAndSettleForData(tester);

    expect(router.routeInformationProvider.value.uri.path, '/onboarding');
    expect(find.text('Page Not Found'), findsNothing);
    expect(find.text('LABAAN'), findsOneWidget);
  });

  testWidgets('wallet is a registered app route', (tester) async {
    setPhoneViewport(tester);
    final router = LabaanApp.createRouter(initialLocation: '/wallet');
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(child: LabaanApp(router: router)));
    await pumpAndSettleForData(tester);

    expect(router.routeInformationProvider.value.uri.path, '/wallet');
    expect(find.text('Wallet'), findsOneWidget);
  });

  testWidgets('normalized tournament deep link opens tournament detail', (
    tester,
  ) async {
    setPhoneViewport(tester);
    final router = LabaanApp.createRouter(
      initialLocation: '/tournament/t_cavite',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(child: LabaanApp(router: router)));
    await pumpAndSettleForData(tester);

    expect(
      router.routeInformationProvider.value.uri.path,
      '/tournament/t_cavite',
    );
    expect(find.text('Tournament'), findsOneWidget);
  });

  testWidgets('Host is a registered organizer destination', (tester) async {
    setPhoneViewport(tester);
    final router = LabaanApp.createRouter(initialLocation: '/host');
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(child: LabaanApp(router: router)));
    await pumpAndSettleForData(tester);

    expect(router.routeInformationProvider.value.uri.path, '/host');
    expect(find.text('Host on Labaan'), findsOneWidget);
  });

  testWidgets('Support is a registered self-service destination', (
    tester,
  ) async {
    setPhoneViewport(tester);
    final router = LabaanApp.createRouter(initialLocation: '/support');
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(child: LabaanApp(router: router)));
    await pumpAndSettleForData(tester);

    expect(router.routeInformationProvider.value.uri.path, '/support');
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('Payout support'), findsOneWidget);
  });
}
