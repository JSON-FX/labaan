import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase bootstrap for the Labaan mobile app.
///
/// Reads credentials from `--dart-define`:
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

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const phoneAuthBypass = bool.fromEnvironment(
    'BYPASS_PHONE_AUTH',
    defaultValue: true,
  );
  static const oauthRedirectUrl = 'com.labaan.labaan://login-callback';

  static bool get configured => _url.isNotEmpty && _anonKey.isNotEmpty;
  static bool get useSupabase => configured;

  static Future<void> init() async {
    if (!configured) return;
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
