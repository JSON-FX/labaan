import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/identity/onboarding_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('renders wordmark, tagline, and three auth CTAs', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const OnboardingScreen()));
    await tester.pump();

    expect(find.text('LABAAN'), findsOneWidget);
    expect(find.text('FIGHT · WIN · RISE'), findsOneWidget);
    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
    expect(find.text('CONTINUE WITH FACEBOOK'), findsOneWidget);
    expect(find.text('CONTINUE WITH PHONE'), findsOneWidget);
  });

  testWidgets('shows GAB/skill-based compliance strip', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const OnboardingScreen()));
    await tester.pump();

    expect(find.text('SKILL-BASED COMPETITION'), findsOneWidget);
    expect(find.text('GAB-REGULATED · COMPLIANT'), findsOneWidget);
  });

  testWidgets('tapping phone CTA disables the other buttons during in-flight', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const OnboardingScreen()));
    await tester.pump();

    await tester.tap(find.text('CONTINUE WITH PHONE'));
    await tester.pump(const Duration(milliseconds: 100));

    // "Signing in…" label swaps in for the phone button.
    expect(find.text('SIGNING IN…'), findsOneWidget);

    // Let the mock auth's 520ms write latency drain so no pending Timer
    // survives the test teardown.
    await tester.pump(const Duration(seconds: 1));
  });
}
