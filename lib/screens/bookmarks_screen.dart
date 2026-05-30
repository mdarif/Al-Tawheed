import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';

// Phase 6: Saved lectures list goes here.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_rounded, size: 52, color: AppColors.onDarkSecondary),
            const SizedBox(height: 16),
            Text(
              'Coming in Phase 6',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Bookmark any lecture from the player',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
