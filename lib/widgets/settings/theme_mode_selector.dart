import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/widgets/selection_chip.dart';

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

    return Row(
      children: _options.map((option) {
        final (mode, label) = option;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SelectionChip(
            label: label,
            selected: themeProvider.themeMode == mode,
            onTap: () {
              HapticFeedback.selectionClick();
              themeProvider.setThemeMode(mode);
            },
          ),
        );
      }).toList(),
    );
  }
}
