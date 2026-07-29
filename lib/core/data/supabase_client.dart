import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase bootstrap for the Labaan mobile app.
///
/// Uses the hosted development backend by default. Credentials can be
/// overridden with `--dart-define`:
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
/// The anon key is safe to ship in the client — Row-Level Security enforces
/// access at the DB (spec §11).
///
/// Init in `main()` **before** `runApp`. `Lb.client` is the SupabaseClient
/// singleton after init.
class Lb {
  Lb._();

  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xmbfzcgejpzvgrfvvfyi.supabase.co',
  );
  static const _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_4n8s3GgG8LQwKuTUR6aJmA_E2SH_3qn',
  );
  static const _forceMocks = bool.fromEnvironment('USE_MOCK_BACKEND');

  static bool get configured => _url.isNotEmpty && _anonKey.isNotEmpty;
  static bool get _isAutomatedTest =>
      Platform.environment['FLUTTER_TEST'] == 'true';
  static bool get useSupabase =>
      configured && !_forceMocks && !_isAutomatedTest;

  static Future<void> init() async {
    if (!useSupabase) return;
    await Supabase.initialize(
      url: _url,
      publishableKey: _anonKey,
      accessToken: () async =>
          await FirebaseAuth.instance.currentUser?.getIdToken(),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
