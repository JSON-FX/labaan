import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/links/payment_link.dart';

void main() {
  const registrationId = '123e4567-e89b-42d3-a456-426614174000';
  const tournamentId = '123e4567-e89b-42d3-a456-426614174001';

  test('success return opens pending until the webhook confirms payment', () {
    final location = paymentLocationFromUri(
      Uri.parse(
        'labaan://payment/success?registrationId=$registrationId&'
        'tournamentId=$tournamentId',
      ),
    );

    expect(
      location,
      '/register/result/pending?registrationId=$registrationId&'
      'tournamentId=$tournamentId',
    );
  });

  test('cancel return opens the failed result with retry available', () {
    final location = paymentLocationFromUri(
      Uri.parse(
        'labaan://payment/cancel?registrationId=$registrationId&'
        'tournamentId=$tournamentId',
      ),
    );

    expect(
      location,
      '/register/result/failed?registrationId=$registrationId&'
      'tournamentId=$tournamentId',
    );
  });

  test('rejects malformed, unrelated, and over-specified return links', () {
    expect(
      paymentLocationFromUri(Uri.parse('https://payment/success')),
      isNull,
    );
    expect(
      paymentLocationFromUri(
        Uri.parse(
          'labaan://payment/success?registrationId=nope&'
          'tournamentId=$tournamentId',
        ),
      ),
      isNull,
    );
    expect(
      paymentLocationFromUri(
        Uri.parse(
          'labaan://payment/success?registrationId=$registrationId&'
          'tournamentId=$tournamentId&next=/settings',
        ),
      ),
      isNull,
    );
  });
}
