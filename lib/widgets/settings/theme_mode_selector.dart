import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/theme/app_colors.dart';

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  static const _options = [
    (ThemeMode.light, 'Light'),
    (ThemeMode.dark, 'Dark'),
    (ThemeMode.system, 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: _options.map((option) {
        final (mode, label) = option;
        final selected = themeProvider.themeMode == mode;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              themeProvider.setThemeMode(mode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold
                    : (isDark
                        ? AppColors.surfaceContainerDark
                        : const Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.black
                      : (isDark
                          ? AppColors.onDarkSecondary
                          : AppColors.onLightSecondary),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
