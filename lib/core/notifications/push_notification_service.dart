import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../data/supabase_client.dart';

typedef PushLocationHandler = void Function(String location);

@visibleForTesting
String? safePushLocation(Object? raw) {
  if (raw is! String || raw.isEmpty || raw.startsWith('//')) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !raw.startsWith('/')) {
    return null;
  }
  const exact = {
    '/home',
    '/browse',
    '/compete',
    '/ranks',
    '/profile',
    '/notifications',
    '/wallet',
    '/settings',
    '/team',
  };
  const prefixes = [
    '/tournament/',
    '/bracket/',
    '/submit-result/',
    '/verify-result/',
    '/dispute/',
    '/settings/',
    '/team/',
  ];
  return exact.contains(uri.path) || prefixes.any(uri.path.startsWith)
      ? raw
      : null;
}

/// Owns the device side of FCM: permission, token lifecycle, foreground
/// presentation, and routing notification taps into the app.
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  final _messaging = FirebaseMessaging.instance;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  PushLocationHandler? _openLocation;
  String? _registeredToken;
  bool _initialized = false;
  bool _pushAllowed = false;

  Future<void> initialize({required PushLocationHandler onOpenLocation}) async {
    if (_initialized) return;
    _initialized = true;
    _openLocation = onOpenLocation;

    try {
      await _messaging.setAutoInitEnabled(true);
      _subscriptions
        ..add(FirebaseMessaging.onMessage.listen(_presentForegroundMessage))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_openMessage))
        ..add(
          _messaging.onTokenRefresh.listen((token) {
            if (_pushAllowed) unawaited(_registerToken(token));
          }),
        )
        ..add(
          FirebaseAuth.instance.idTokenChanges().listen((user) {
            if (user != null) unawaited(_enableForCurrentUser());
          }),
        );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openMessage(initialMessage),
        );
      }
    } catch (error, stackTrace) {
      _debug('Push initialization failed', error, stackTrace);
    }
  }

  Future<void> unregisterCurrentToken() async {
    if (!Lb.useSupabase || FirebaseAuth.instance.currentUser == null) return;
    try {
      final token = _registeredToken ?? await _messaging.getToken();
      if (token == null) return;
      await Lb.client.rpc('unregister_push_device', params: {'p_token': token});
      _registeredToken = null;
    } catch (error, stackTrace) {
      // Signing out must remain possible during a transient backend outage.
      _debug('Push unregistration failed', error, stackTrace);
    }
  }

  bool _permissionAllowsPush(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  Future<void> _enableForCurrentUser() async {
    try {
      // Ask only after authentication instead of interrupting onboarding.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _pushAllowed = _permissionAllowsPush(settings.authorizationStatus);
      if (!_pushAllowed) return;
      if (Platform.isIOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      await _registerCurrentToken();
    } catch (error, stackTrace) {
      _debug('Could not enable push notifications', error, stackTrace);
    }
  }

  Future<void> _registerCurrentToken() async {
    if (!Lb.useSupabase || FirebaseAuth.instance.currentUser == null) return;
    try {
      // On Apple platforms FCM token calls are only valid after APNs has
      // supplied its token. Allow registration a few seconds to settle on a
      // fresh install; onTokenRefresh remains the long-term fallback.
      if (Platform.isIOS) {
        var apnsToken = await _messaging.getAPNSToken();
        for (var attempt = 0; apnsToken == null && attempt < 10; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          apnsToken = await _messaging.getAPNSToken();
        }
        if (apnsToken == null) return;
      }
      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (error, stackTrace) {
      _debug('Could not read the FCM token', error, stackTrace);
    }
  }

  Future<void> _registerToken(String token) async {
    if (!Lb.useSupabase || FirebaseAuth.instance.currentUser == null) return;
    try {
      final previous = _registeredToken;
      if (previous != null && previous != token) {
        await Lb.client.rpc(
          'unregister_push_device',
          params: {'p_token': previous},
        );
      }
      await Lb.client.rpc(
        'register_push_device',
        params: {
          'p_token': token,
          'p_platform': Platform.isIOS ? 'ios' : 'android',
          'p_app_variant': appFlavor == 'prod' ? 'prod' : 'dev',
        },
      );
      _registeredToken = token;
    } catch (error, stackTrace) {
      _debug('Could not register the FCM token', error, stackTrace);
    }
  }

  void _presentForegroundMessage(RemoteMessage message) {
    // iOS displays the configured system banner. Android suppresses system
    // notifications in the foreground, so provide an in-app banner instead.
    if (Platform.isIOS) return;
    final title = message.notification?.title ?? 'Labaan update';
    final body = message.notification?.body;
    final location = safePushLocation(message.data['deep_link']);
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(body == null || body.isEmpty ? title : '$title\n$body'),
          action: location == null
              ? null
              : SnackBarAction(
                  label: 'OPEN',
                  onPressed: () => _openLocation?.call(location),
                ),
        ),
      );
  }

  void _openMessage(RemoteMessage message) {
    final location = safePushLocation(message.data['deep_link']);
    if (location != null) _openLocation?.call(location);
  }

  void _debug(String message, Object error, StackTrace stackTrace) {
    if (kDebugMode) debugPrint('$message: $error\n$stackTrace');
  }
}
