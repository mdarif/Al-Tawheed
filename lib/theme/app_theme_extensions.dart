import 'package:flutter/material.dart';
import 'package:myapp/theme/app_semantic_colors.dart';

/// Convenience accessors for theme tokens in widgets.
/// Widgets should use these — not raw palette constants.
extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);

  ColorScheme get colorScheme => appTheme.colorScheme;

  TextTheme get textTheme => appTheme.textTheme;

  AppSemanticColors get semantic =>
      appTheme.extension<AppSemanticColors>()!;

  bool get isDarkTheme => appTheme.brightness == Brightness.dark;

  Color get primaryTextColor => colorScheme.onSurface;

  Color get secondaryTextColor => colorScheme.onSurfaceVariant;

  Color get mutedIconColor => colorScheme.onSurfaceVariant;

  Color get groupedSurface => semantic.groupedSurface;

  Color get groupedBorder => semantic.groupedBorder;

  Color get elevatedSurface => semantic.elevatedSurface;

  Color get chipUnselectedBackground => semantic.elevatedSurface;

  Color get chipUnselectedText => colorScheme.onSurfaceVariant;

  Color get dividerColor => semantic.groupedBorder;

  Color get progressTrackColor => semantic.progressTrack;

  Color get surfaceTintColor => semantic.surfaceTint;

  Color get brandColor => semantic.brand;

  Color get onBrandColor => semantic.onBrand;
}
