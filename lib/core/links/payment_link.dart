final _paymentIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Converts a PayMongo return URI into the existing payment-result route.
/// The redirect is navigation only: the result screen still observes the
/// backend registration row before treating a payment as settled.
String? paymentLocationFromUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'labaan' ||
      uri.host.toLowerCase() != 'payment' ||
      uri.fragment.isNotEmpty ||
      uri.pathSegments.length != 1) {
    return null;
  }

  final purpose = uri.queryParameters['purpose'];
  if (purpose == 'credit_topup' && uri.queryParameters.length == 1) {
    return switch (uri.pathSegments.single.toLowerCase()) {
      'success' => '/wallet?topupResult=pending',
      'cancel' => '/wallet?topupResult=cancelled',
      _ => null,
    };
  }

  final registrationId = uri.queryParameters['registrationId'];
  final tournamentId = uri.queryParameters['tournamentId'];
  if (registrationId == null ||
      tournamentId == null ||
      !_paymentIdPattern.hasMatch(registrationId) ||
      !_paymentIdPattern.hasMatch(tournamentId) ||
      uri.queryParameters.keys.any(
        (key) => key != 'registrationId' && key != 'tournamentId',
      )) {
    return null;
  }

  final result = switch (uri.pathSegments.single.toLowerCase()) {
    'success' => 'pending',
    'cancel' => 'failed',
    _ => null,
  };
  if (result == null) return null;

  return Uri(
    path: '/register/result/$result',
    queryParameters: {
      'registrationId': registrationId,
      'tournamentId': tournamentId,
    },
  ).toString();
}
