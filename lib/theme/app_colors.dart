import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  // Warm gold — replaces lime green; reads as premium Islamic aesthetic.
  static const Color gold = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE8C97A);
  static const Color goldDark = Color(0xFF9A7C34);

  // ── Dark surface palette ────────────────────────────────────────────────
  // iOS-native charcoal tones — easier on the eye than pure black.
  static const Color backgroundDark = Color(0xFF1C1C1E);
  static const Color surfaceDark = Color(0xFF2C2C2E);
  static const Color surfaceContainerDark = Color(0xFF3A3A3C);
  static const Color surfaceTintDark = Color(0xFF48484A);

  // ── Light surface palette ───────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLight = Color(0xFFE5E5EA);
  static const Color surfaceTintLight = Color(0xFFD1D1D6);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color onDark = Color(0xFFEBEBF5);       // primary text on dark
  static const Color onDarkSecondary = Color(0xFF8E8E93); // secondary/hint on dark
  static const Color onLight = Color(0xFF1C1C1E);
  static const Color onLightSecondary = Color(0xFF6C6C70);

  // ── Semantic ────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF453A);        // iOS red
  static const Color success = Color(0xFF30D158);      // iOS green
}
