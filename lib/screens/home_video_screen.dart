// Phase 1 placeholder — YouTube API and player removed.
// Replaced with lecture list in Phase 2 (catalog_service + lecture_list_screen).
import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';
import 'main_drawer.dart';

class HomeVideoScreen extends StatelessWidget {
  const HomeVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sharah Kitab al-Tawheed')),
      drawer: MainDrawer(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 24),
            Text(
              'Setting up audio player…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Phase 2 coming next',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
