import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/data/supabase_client.dart';
import 'core/links/tournament_link_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/font_licenses.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F1116),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // No-op unless --dart-define=SUPABASE_URL / SUPABASE_ANON_KEY are set.
  await Lb.init();
  TournamentLinkService.instance.initialize(
    onOpenLocation: LabaanApp.openPushLocation,
  );
  runApp(const ProviderScope(child: LabaanApp()));
  unawaited(
    PushNotificationService.instance.initialize(
      onOpenLocation: LabaanApp.openPushLocation,
    ),
  );
}
