import 'package:flutter/material.dart';

/// Platform-aware typography built on Material 3 scales.
///
/// iOS: tighter title tracking (SF Pro conventions).
/// Android: Material default tracking (Roboto).
class AppTypography {
  AppTypography._();

  static TextTheme create({
    required Brightness brightness,
    required TargetPlatform platform,
    required ColorScheme colorScheme,
  }) {
    final isIOS = platform == TargetPlatform.iOS;
    final typography = Typography.material2021(
      platform: platform,
      colorScheme: colorScheme,
    );
    final base =
        brightness == Brightness.dark ? typography.white : typography.black;

    final primary = colorScheme.onSurface;
    final secondary = colorScheme.onSurfaceVariant;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        letterSpacing: isIOS ? -1.0 : -0.5,
        height: 1.15,
        color: primary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: isIOS ? -0.4 : 0,
        color: primary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: isIOS ? -0.4 : 0,
        color: primary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: isIOS ? -0.3 : 0,
        color: primary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        height: isIOS ? 1.4 : 1.5,
        color: primary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: isIOS ? 1.4 : 1.5,
        color: primary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: isIOS ? 1.35 : 1.4,
        color: secondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: isIOS ? 0.5 : 0.25,
        color: primary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: isIOS ? 1.2 : 0.8,
        color: colorScheme.primary,
      ),
    );
  }
}
