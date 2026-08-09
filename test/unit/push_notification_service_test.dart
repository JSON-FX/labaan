import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/notifications/push_notification_service.dart';

void main() {
  test('accepts allow-listed notification routes and preserves queries', () {
    expect(safePushLocation('/notifications'), '/notifications');
    expect(safePushLocation('/wallet'), '/wallet');
    expect(
      safePushLocation('/tournament/sunday-night?source=push'),
      '/tournament/sunday-night?source=push',
    );
  });

  test('rejects external and scheme-relative notification links', () {
    expect(safePushLocation('https://example.com/phish'), isNull);
    expect(safePushLocation('//example.com/phish'), isNull);
  });

  test('rejects unknown internal routes', () {
    expect(safePushLocation('/admin/users'), isNull);
    expect(safePushLocation(null), isNull);
  });
}
