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

    test('secondary text meets WCAG AA on the light surface', () {
      final theme = AppTheme.light;
      final semantic = theme.extension<AppSemanticColors>()!;

      // This is intentionally an exact ratio check, not a snapshot: the old
      // muted grey was below the 4.5:1 normal-text threshold.
      expect(
        _contrastRatio(semantic.secondaryText, theme.colorScheme.surface),
        closeTo(5.9675, 0.001),
      );
      expect(semantic.secondaryText, theme.colorScheme.onSurfaceVariant);
    });

    test('secondary text meets WCAG AA on the dark surface', () {
      final theme = AppTheme.dark;
      final semantic = theme.extension<AppSemanticColors>()!;

      expect(
        _contrastRatio(semantic.secondaryText, theme.colorScheme.surface),
        closeTo(5.3532, 0.001),
      );
      expect(semantic.secondaryText, theme.colorScheme.onSurfaceVariant);
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

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
