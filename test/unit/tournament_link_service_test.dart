import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/links/tournament_link_service.dart';

void main() {
  test('builds the locked tournament share URI', () {
    expect(
      tournamentShareUri('f0000000-0000-0000-0000-000000000001').toString(),
      'labaan://tournament/f0000000-0000-0000-0000-000000000001',
    );
  });

  test('normalizes host-style and path-style tournament links', () {
    expect(
      tournamentLocationFromUri(Uri.parse('labaan://tournament/t_cavite')),
      '/tournament/t_cavite',
    );
    expect(
      tournamentLocationFromUri(Uri.parse('labaan:///tournament/t_cavite')),
      '/tournament/t_cavite',
    );
  });

  test('rejects unrelated, malformed, and injectable links', () {
    expect(
      tournamentLocationFromUri(
        Uri.parse('com.labaan.labaan://login-callback'),
      ),
      isNull,
    );
    expect(
      tournamentLocationFromUri(Uri.parse('labaan://profile/t_cavite')),
      isNull,
    );
    expect(
      tournamentLocationFromUri(
        Uri.parse('labaan://tournament/t_cavite/extra'),
      ),
      isNull,
    );
    expect(
      tournamentLocationFromUri(
        Uri.parse('labaan://tournament/t_cavite?redirect=/settings'),
      ),
      isNull,
    );
  });

  test('dispatches a PayMongo return through the shared app-link handler', () {
    expect(
      appLocationFromUri(
        Uri.parse(
          'labaan://payment/success?'
          'registrationId=123e4567-e89b-42d3-a456-426614174000&'
          'tournamentId=d0000000-0000-0000-0000-000000000004',
        ),
      ),
      '/register/result/pending?'
      'registrationId=123e4567-e89b-42d3-a456-426614174000&'
      'tournamentId=d0000000-0000-0000-0000-000000000004',
    );
  });
}
