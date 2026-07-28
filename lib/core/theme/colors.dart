import 'package:flutter/material.dart';

/// Labaan palette — dark cyber-esports.
/// Ports the design's oklch/hex values into Flutter [Color] constants.
class LbColors {
  LbColors._();

  // Surfaces
  static const canvas = Color(0xFF0E1013); // design-canvas backdrop
  static const bg = Color(0xFF0F1116); // primary app background
  static const bgAlt = Color(0xFF16181E); // dimmed / passive rows
  static const surface = Color(0xFF1A1D24); // cards, inputs
  static const surfaceHi = Color(0xFF262A33); // pressed / stepper button

  // Borders / dividers
  static const border = Color(0xFF31353F);
  static const borderMuted = Color(0xFF262932);

  // Text
  static const textPrimary = Color(0xFFECEEF2);
  static const textPrimaryHi = Color(0xFFF2F4F8);
  static const textSecondary = Color(0xFFC7CAD2);
  static const textMuted = Color(0xFF969AA5);
  static const textDim = Color(0xFF61656F);

  // Accents — oklch(0.87 0.19 126) sits ~ #B8F041 lime
  static const lime = Color(0xFFB8F041);
  static const limeBright = Color(0xFFC7F958);
  static const limeInk = Color(0xFF10130A); // ink-on-lime

  // Semantic
  static const danger = Color(0xFFFF5A5A); // oklch(0.66 0.2 26)
  static const gold = Color(0xFFD4AF37); // premium tier
  static const info = Color(0xFF4A90C8);
  static const purple = Color(0xFF7828C8);

  // Game key-art gradient stops (used as placeholders on cards)
  static const valStart = Color(0xFF2A0F3E);
  static const valMid = Color(0xFF7A1050);
  static const valEnd = Color(0xFFFF4655);

  static const mlbbStart = Color(0xFF0B2540);
  static const mlbbMid = Color(0xFF124A7A);
  static const mlbbEnd = Color(0xFFF5A623);

  static const tekkenStart = Color(0xFF4A0A2E);
  static const tekkenMid = Color(0xFF8A1543);
  static const tekkenEnd = Color(0xFFD4AF37);

  // Payment tile gradients
  static const gcashStart = Color(0xFF007DFF);
  static const gcashEnd = Color(0xFF003A8C);
  static const mayaStart = Color(0xFF00C46A);
  static const mayaEnd = Color(0xFF005A30);
}
