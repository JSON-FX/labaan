import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Type ramp mirroring the design's three families:
///  - Chakra Petch: headings, buttons, numerals-with-attitude
///  - IBM Plex Sans: body copy
///  - IBM Plex Mono: labels, timers, "// section" prefixes, tabular data
class LbType {
  LbType._();

  static TextStyle _chakra({
    required double size,
    FontWeight weight = FontWeight.w700,
    double letter = 0,
    Color color = LbColors.textPrimary,
    double? height,
  }) => GoogleFonts.chakraPetch(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letter,
    color: color,
    height: height,
  );

  static TextStyle _sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    double letter = 0,
    Color color = LbColors.textPrimary,
    double? height,
  }) => GoogleFonts.ibmPlexSans(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letter,
    color: color,
    height: height,
  );

  static TextStyle _mono({
    required double size,
    FontWeight weight = FontWeight.w500,
    double letter = 0.5,
    Color color = LbColors.textMuted,
    double? height,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letter,
    color: color,
    height: height,
  );

  // Display / headings
  static TextStyle get wordmark => _chakra(
    size: 46,
    weight: FontWeight.w700,
    letter: 6,
    color: LbColors.textPrimaryHi,
    height: 1.0,
  );
  static TextStyle get takeoverTitle =>
      _chakra(size: 40, letter: 4, color: LbColors.textPrimaryHi, height: 1.0);
  static TextStyle get screenTitle => _chakra(size: 22, letter: -0.3);
  static TextStyle get sectionTitle => _chakra(size: 18, letter: -0.2);
  static TextStyle get cardTitle => _chakra(size: 14, letter: -0.1);
  static TextStyle get cardTitleSm => _chakra(size: 13, letter: -0.1);

  // Buttons
  static TextStyle get button =>
      _chakra(size: 14, letter: 0.5, color: LbColors.limeInk);
  static TextStyle get buttonSm =>
      _chakra(size: 11, letter: 0.5, color: LbColors.limeInk);

  // Body
  static TextStyle get body =>
      _sans(size: 13, color: LbColors.textPrimary, height: 1.45);
  static TextStyle get bodySm =>
      _sans(size: 12, color: LbColors.textSecondary, height: 1.4);
  static TextStyle get bodyXs =>
      _sans(size: 11, color: LbColors.textSecondary, height: 1.4);

  // Mono utilities
  static TextStyle get sectionLabel => _mono(
    size: 10,
    weight: FontWeight.w500,
    letter: 1.6,
    color: LbColors.textDim,
  );
  static TextStyle get metaLabel => _mono(size: 10, letter: 0.8);
  static TextStyle get metaSm => _mono(size: 9, letter: 0.5);
  static TextStyle get timerHot =>
      _mono(size: 10, weight: FontWeight.w600, color: LbColors.danger);
  static TextStyle get moneyBig =>
      _chakra(size: 19, color: LbColors.lime, height: 1.0);
  static TextStyle get money =>
      _mono(size: 12.5, weight: FontWeight.w500, color: LbColors.textPrimary);

  // Numerals for rank badges / big stats
  static TextStyle rankNumeral(double size, {Color? color}) => _chakra(
    size: size,
    weight: FontWeight.w700,
    color: color ?? LbColors.textPrimary,
    height: 1.0,
  );
}
