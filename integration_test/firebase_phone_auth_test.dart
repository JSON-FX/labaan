import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:labaan/core/data/firebase_auth_repo.dart';
import 'package:labaan/core/data/models.dart';
import 'package:labaan/core/data/supabase_client.dart';
import 'package:labaan/core/data/supabase_repos.dart';
import 'package:labaan/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase test phone signs into the hosted Supabase profile', (
    tester,
  ) async {
    const phone = String.fromEnvironment('FIREBASE_TEST_PHONE');
    const code = String.fromEnvironment('FIREBASE_TEST_CODE');
    if (phone.isEmpty || code.isEmpty) {
      fail('Pass FIREBASE_TEST_PHONE and FIREBASE_TEST_CODE as dart-defines.');
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await Lb.init();
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    final repo = FirebaseAuthRepo(Lb.client);
    await repo.requestPhoneOtp(phone);
    final autoVerified = await repo.currentUser();
    final user =
        autoVerified ??
        await repo.verifyPhoneOtp(phoneE164: phone, token: code);

    expect(user.phone, phone);
    expect(
      user.id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );

    final profile = await Lb.client
        .from('profiles')
        .select('id, firebase_uid')
        .eq('id', user.id)
        .single();
    expect(profile['firebase_uid'], auth.currentUser?.uid);

    final settings = SupabaseSettingsRepo(Lb.client);
    final defaults = LbNotificationPreferences.defaults();
    final changedPush = Map.of(defaults.push)..[NotifKind.matchReady] = false;
    await settings.saveNotificationPreferences(
      user.id,
      defaults.copyWith(push: changedPush),
    );
    final savedPreferences = await settings.notificationPreferences(user.id);
    expect(savedPreferences.push[NotifKind.matchReady], isFalse);
    await settings.saveNotificationPreferences(user.id, defaults);

    final payout = LbPayoutAccount(
      provider: 'gcash',
      accountName: 'Firebase Test',
      mobileNumber: phone,
    );
    await settings.savePayoutAccount(user.id, payout);
    final savedPayout = await settings.payoutAccount(user.id);
    expect(savedPayout?.provider, 'gcash');
    expect(savedPayout?.mobileNumber, phone);
    await settings.deletePayoutAccount(user.id);
    expect(await settings.payoutAccount(user.id), isNull);

    final registrations = SupabaseRegistrationRepo(Lb.client);
    final checkout = await registrations.register(
      tournamentId: 'd0000000-0000-0000-0000-000000000004',
      userId: user.id,
      method: PayMethod.gcash,
      captchaToken: 'integration-test',
    );
    expect(checkout.registration.paymentStatus, RegistrationPaymentStatus.paid);
    expect(checkout.registration.paymongoRef, startsWith('paymongo_mock_'));

    await repo.signOut();
  });
}
