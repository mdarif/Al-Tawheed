import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';

// Phase 6: Playback speed, theme toggle, contact/share/rate go here.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_rounded, size: 52, color: AppColors.onDarkSecondary),
            const SizedBox(height: 16),
            Text(
              'Coming in Phase 6',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Speed · Theme · Contact · Rate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
