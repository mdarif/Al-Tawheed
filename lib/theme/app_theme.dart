import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/theme/app_semantic_colors.dart';
import 'package:myapp/theme/app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        platform: defaultTargetPlatform,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        platform: defaultTargetPlatform,
      );

  static ThemeData _build({
    required Brightness brightness,
    required TargetPlatform platform,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark ? _darkScheme : _lightScheme;
    final semantic = isDark
        ? AppSemanticColors.dark(colorScheme)
        : AppSemanticColors.light(colorScheme);
    final textTheme = AppTypography.create(
      brightness: brightness,
      platform: platform,
      colorScheme: colorScheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      platform: platform,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      extensions: [semantic],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: semantic.brandSubtle,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? semantic.brand : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontSize: 12,
            color: selected ? semantic.brand : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: semantic.brand,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: semantic.onBrand,
          backgroundColor: semantic.brand,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: semantic.onBrand,
          backgroundColor: semantic.brand,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: semantic.brand,
        textColor: colorScheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: semantic.groupedBorder,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: semantic.brand,
        thumbColor: semantic.brand,
        inactiveTrackColor: semantic.surfaceTint,
        overlayColor: semantic.brand.withValues(alpha: 0.16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: semantic.brand,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  static const _darkScheme = ColorScheme.dark(
    primary: AppColors.gold,
    onPrimary: AppColors.onLight,
    secondary: AppColors.goldLight,
    onSecondary: AppColors.onLight,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onDark,
    onSurfaceVariant: AppColors.onDarkSecondary,
    surfaceContainerHighest: AppColors.surfaceContainerDark,
    error: AppColors.error,
  );

  static const _lightScheme = ColorScheme.light(
    primary: AppColors.goldLightTheme,
    onPrimary: AppColors.onGoldLight,
    secondary: AppColors.goldLightThemeDark,
    onSecondary: AppColors.onLight,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.onLight,
    onSurfaceVariant: AppColors.onLightSecondary,
    surfaceContainerHighest: AppColors.surfaceContainerLight,
    error: AppColors.error,
  );
}
