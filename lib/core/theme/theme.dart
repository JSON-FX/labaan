import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';
import 'typography.dart';

/// Fast crossfade between routes — snappier than the default Material
/// slide-up and less jarring against Labaan's dark theme.
class _FadeThroughTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: child,
    );
  }
}

class LbTheme {
  LbTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      surface: LbColors.bg,
      primary: LbColors.lime,
      onPrimary: LbColors.limeInk,
      secondary: LbColors.gold,
      error: LbColors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: LbColors.bg,
      canvasColor: LbColors.bg,
      textTheme: TextTheme(
        titleLarge: LbType.screenTitle,
        titleMedium: LbType.sectionTitle,
        titleSmall: LbType.cardTitle,
        bodyLarge: LbType.body,
        bodyMedium: LbType.bodySm,
        bodySmall: LbType.bodyXs,
        labelLarge: LbType.button,
        labelSmall: LbType.metaSm,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: LbColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: LbType.screenTitle,
        iconTheme: const IconThemeData(color: LbColors.textSecondary),
      ),
      cardTheme: const CardThemeData(
        color: LbColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: LbColors.border),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: LbColors.borderMuted,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LbColors.surface,
        contentTextStyle: LbType.body.copyWith(color: LbColors.textPrimary),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: LbColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: LbColors.lime,
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: _FadeThroughTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LbColors.surface,
        hintStyle: LbType.bodySm.copyWith(color: LbColors.textDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: LbColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: LbColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: LbColors.lime, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
