import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.light(primary: AppColors.primary),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          elevation: 2,
          centerTitle: true,
          systemOverlayStyle:
              const SystemUiOverlayStyle(statusBarBrightness: Brightness.light),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontStyle: FontStyle.normal,
            color: Colors.black87,
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: AppColors.primary,
          ),
        ),
      );
}
