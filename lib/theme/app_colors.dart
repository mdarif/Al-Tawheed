import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand (dark theme) ───────────────────────────────────────────────────
  // Warm gold — unchanged for dark mode.
  static const Color gold = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE8C97A);
  static const Color goldDark = Color(0xFF9A7C34);

  // ── Brand (light theme — palette B: rich gold + cream) ───────────────────
  static const Color goldLightTheme = Color(0xFFD4AF37);
  static const Color goldLightThemeLight = Color(0xFFE8C75A);
  static const Color goldLightThemeDark = Color(0xFFA6841F);
  static const Color brandSubtleLight = Color(0xFFFBF3E0);
  static const Color onGoldLight = Color(0xFFFFFFFF);

  // ── Dark surface palette ────────────────────────────────────────────────
  // iOS-native charcoal tones — easier on the eye than pure black.
  static const Color backgroundDark = Color(0xFF141416);
  static const Color surfaceDark = Color(0xFF2C2C2E);
  static const Color surfaceContainerDark = Color(0xFF3A3A3C);
  static const Color surfaceTintDark = Color(0xFF48484A);

  // ── Light surface palette (warm cream neutrals) ───────────────────────────
  static const Color backgroundLight = Color(0xFFFAF8F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLight = Color(0xFFE8E2D8);
  static const Color surfaceTintLight = Color(0xFFDDD4C8);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color onDark = Color(0xFFEBEBF5); // primary text on dark
  static const Color onDarkSecondary =
      Color(0xFF8E8E93); // secondary/hint on dark
  static const Color onLight = Color(0xFF141416);
  static const Color onLightSecondary = Color(0xFF6C6256);

  // ── Semantic ────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF453A); // iOS red
  static const Color success = Color(0xFF30D158); // iOS green
}
