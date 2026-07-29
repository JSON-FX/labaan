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

  testWidgets('tapping phone CTA opens the OTP flow', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const OnboardingScreen()));
    await tester.pump();

    await tester.tap(find.text('CONTINUE WITH PHONE'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Your mobile number'), findsOneWidget);
  });
}
