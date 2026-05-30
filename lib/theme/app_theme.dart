import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Dark (default) ──────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          onPrimary: AppColors.onLight,
          secondary: AppColors.goldLight,
          onSecondary: AppColors.onLight,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onDark,
          surfaceContainerHighest: AppColors.surfaceContainerDark,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.onDark,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.onDark,
            letterSpacing: -0.4,
          ),
          iconTheme: IconThemeData(color: AppColors.onDark),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.onDarkSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surfaceDark,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: AppColors.onLight,
            backgroundColor: AppColors.gold,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppColors.gold,
          textColor: AppColors.onDark,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.surfaceContainerDark,
          thickness: 1,
          space: 1,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.gold,
          thumbColor: AppColors.gold,
          inactiveTrackColor: AppColors.surfaceTintDark,
          overlayColor: Color(0x29C9A84C),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.gold,
        ),
        iconTheme: const IconThemeData(color: AppColors.onDark),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: AppColors.onDark,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
          titleMedium: TextStyle(
            color: AppColors.onDark,
            fontWeight: FontWeight.w500,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
          bodyMedium: TextStyle(color: AppColors.onDark, fontSize: 14),
          bodySmall: TextStyle(color: AppColors.onDarkSecondary, fontSize: 12),
          labelSmall: TextStyle(
            color: AppColors.onDarkSecondary,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      );

  // ── Light (available via Settings toggle) ───────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.gold,
          onPrimary: AppColors.onLight,
          secondary: AppColors.goldDark,
          onSecondary: AppColors.surfaceLight,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.onLight,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.onLight,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.onLight,
            letterSpacing: -0.4,
          ),
          iconTheme: IconThemeData(color: AppColors.onLight),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.onLightSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surfaceLight,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: AppColors.onLight,
            backgroundColor: AppColors.gold,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppColors.gold,
          textColor: AppColors.onLight,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.gold,
          thumbColor: AppColors.gold,
          inactiveTrackColor: Color(0xFFD1D1D6),
          overlayColor: Color(0x29C9A84C),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.gold,
        ),
      );
}
