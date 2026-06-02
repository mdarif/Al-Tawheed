import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/theme/app_semantic_colors.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/theme/app_typography.dart';

void main() {
  group('AppTheme', () {
    test('light and dark themes register AppSemanticColors extension', () {
      expect(AppTheme.light.extension<AppSemanticColors>(), isNotNull);
      expect(AppTheme.dark.extension<AppSemanticColors>(), isNotNull);
    });

    test('light theme uses palette B gold tokens', () {
      final light = AppTheme.light;
      expect(light.colorScheme.primary, AppColors.goldLightTheme);
      expect(light.colorScheme.onPrimary, AppColors.onGoldLight);
      expect(
        light.extension<AppSemanticColors>()!.brandSubtle,
        AppColors.brandSubtleLight,
      );
      expect(light.scaffoldBackgroundColor, AppColors.backgroundLight);
    });

    test('dark theme keeps original gold primary', () {
      expect(AppTheme.dark.colorScheme.primary, AppColors.gold);
    });

    test('iOS typography uses tighter title tracking than Android', () {
      final ios = AppTypography.create(
        brightness: Brightness.light,
        platform: TargetPlatform.iOS,
        colorScheme: AppTheme.light.colorScheme,
      );
      final android = AppTypography.create(
        brightness: Brightness.light,
        platform: TargetPlatform.android,
        colorScheme: AppTheme.light.colorScheme,
      );

      expect(
        ios.titleLarge!.letterSpacing!,
        lessThan(android.titleLarge!.letterSpacing!),
      );
    });
  });
}
