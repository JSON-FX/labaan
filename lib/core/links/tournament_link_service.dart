import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'payment_link.dart';

typedef TournamentLocationHandler = void Function(String location);

final _tournamentIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

Uri tournamentShareUri(String tournamentId) {
  if (!_tournamentIdPattern.hasMatch(tournamentId)) {
    throw ArgumentError.value(tournamentId, 'tournamentId');
  }
  return Uri(scheme: 'labaan', host: 'tournament', path: '/$tournamentId');
}

@visibleForTesting
String? tournamentLocationFromUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'labaan' ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return null;
  }

  final segments = uri.host.toLowerCase() == 'tournament'
      ? uri.pathSegments
      : uri.host.isEmpty &&
            uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first.toLowerCase() == 'tournament'
      ? uri.pathSegments.skip(1).toList()
      : const <String>[];
  if (segments.length != 1 || !_tournamentIdPattern.hasMatch(segments.single)) {
    return null;
  }
  return '/tournament/${segments.single}';
}

@visibleForTesting
String? appLocationFromUri(Uri uri) =>
    tournamentLocationFromUri(uri) ?? paymentLocationFromUri(uri);

/// Converts platform custom-scheme events into the app's existing GoRouter
/// tournament and payment-result routes. Other schemes and malformed links
/// are deliberately ignored, including OAuth callbacks handled by plugins.
class TournamentLinkService {
  TournamentLinkService._();

  static final instance = TournamentLinkService._();

  StreamSubscription<Uri>? _subscription;

  void initialize({required TournamentLocationHandler onOpenLocation}) {
    if (_subscription != null) return;
    final appLinks = AppLinks();

    void open(Uri uri) {
      final location = appLocationFromUri(uri);
      if (location != null) onOpenLocation(location);
    }

    void reportError(Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('App link handling failed: $error\n$stackTrace');
      }
    }

    Future<void> openInitialLink() async {
      try {
        final uri = await appLinks.getInitialLink();
        if (uri != null) open(uri);
      } catch (error, stackTrace) {
        reportError(error, stackTrace);
      }
    }

    _subscription = appLinks.uriLinkStream.listen((uri) {
      open(uri);
    }, onError: reportError);
    unawaited(openInitialLink());
  }
}
