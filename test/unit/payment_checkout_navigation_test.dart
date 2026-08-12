import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/registration/payment_checkout_screen.dart';

void main() {
  const registrationId = '123e4567-e89b-42d3-a456-426614174000';
  const tournamentId = '123e4567-e89b-42d3-a456-426614174001';

  test('keeps ordinary PayMongo and provider pages in the WebView', () {
    expect(
      classifyCheckoutNavigation(
        Uri.parse('https://checkout.paymongo.com/x'),
      ).kind,
      CheckoutNavigationKind.web,
    );
    expect(
      classifyCheckoutNavigation(Uri.parse('about:blank')).kind,
      CheckoutNavigationKind.web,
    );
  });

  test('converts a valid app return into the payment result location', () {
    final navigation = classifyCheckoutNavigation(
      Uri.parse(
        'labaan://payment/success?registrationId=$registrationId&'
        'tournamentId=$tournamentId',
      ),
    );

    expect(navigation.kind, CheckoutNavigationKind.appReturn);
    expect(
      navigation.appLocation,
      '/register/result/pending?registrationId=$registrationId&'
      'tournamentId=$tournamentId',
    );
  });

  test('converts a Credit top-up return into a wallet refresh location', () {
    final navigation = classifyCheckoutNavigation(
      Uri.parse('labaan://payment/success?purpose=credit_topup'),
    );

    expect(navigation.kind, CheckoutNavigationKind.appReturn);
    expect(navigation.appLocation, '/wallet?topupResult=pending');
  });

  test('hands native wallet schemes to the operating system', () {
    expect(
      classifyCheckoutNavigation(Uri.parse('gcash://pay/example')).kind,
      CheckoutNavigationKind.externalApp,
    );
  });

  test('blocks malformed Labaan return links', () {
    expect(
      classifyCheckoutNavigation(Uri.parse('labaan://payment/success')).kind,
      CheckoutNavigationKind.blocked,
    );
  });
}
