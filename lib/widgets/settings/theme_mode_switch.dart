import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Single-tap dark mode control — CupertinoSwitch on iOS, Material Switch on Android.
class ThemeModeSwitch extends StatelessWidget {
  const ThemeModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.semantic.brandSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          color: context.brandColor,
          size: 20,
        ),
      ),
      title: Text(
        isDark ? l10n.settingsDarkMode : l10n.settingsLightMode,
        style: context.textTheme.bodyMedium,
      ),
      value: isDark,
      activeTrackColor: context.brandColor.withValues(alpha: 0.5),
      activeThumbColor: context.brandColor,
      onChanged: (enabled) {
        HapticFeedback.selectionClick();
        themeProvider.setDarkMode(enabled);
      },
    );
  }
}
