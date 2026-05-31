import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme/app_semantic_colors.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/theme/app_typography.dart';

void main() {
  group('AppTheme', () {
    test('light and dark themes register AppSemanticColors extension', () {
      expect(AppTheme.light.extension<AppSemanticColors>(), isNotNull);
      expect(AppTheme.dark.extension<AppSemanticColors>(), isNotNull);
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
