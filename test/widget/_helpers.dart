import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:labaan/core/theme/theme.dart';

/// Point the test surface at a modern iPhone-ish viewport. Default test
/// surface is 800×600 which is too short for our vertically-laid onboarding
/// / setup / dispute screens (Column overflows or ListView items go below
/// fold). Restores on tearDown.
///
/// Call at the top of any `testWidgets` block that pumps a Labaan screen.
void setPhoneViewport(
  WidgetTester tester, {
  double width = 400,
  double height = 900,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = ui.Size(width, height);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Wrap [child] in a ProviderScope + MaterialApp so a screen can be pumped
/// stand-alone. The mock repos are the default provider bindings, so we
/// don't need to inject overrides.
Widget hostScreen(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: LbTheme.dark,
      home: child,
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// Host a widget under a mini go_router with a single named route so screens
/// that call `context.push/go` don't blow up.
Widget hostRoute(Widget child, {String path = '/'}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: path, builder: (_, _) => child),
      // Sink for any nav the screen might attempt.
      GoRoute(path: '/_sink/:name', builder: (_, _) => const _Sink()),
    ],
    // Redirect any unknown push to /_sink so tests don't crash on
    // uncovered nav paths.
    redirect: (context, state) {
      final loc = state.uri.path;
      if (loc == path || loc.startsWith('/_sink')) return null;
      return '/_sink/${Uri.encodeComponent(loc)}';
    },
  );
  return ProviderScope(
    child: MaterialApp.router(
      theme: LbTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

class _Sink extends StatelessWidget {
  const _Sink();
  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

/// Pumps a frame, then waits ~1s of virtual time for mock repo latencies
/// (320ms read + jitter) to complete.
///
/// Deliberately does NOT call `pumpAndSettle` — several screens have
/// deliberate infinite animations (LIVE pulse dot, rank-up glow) that would
/// starve `pumpAndSettle` forever.
Future<void> pumpAndSettleForData(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}
