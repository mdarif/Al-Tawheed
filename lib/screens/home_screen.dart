import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';

// Phase 5: Continue Listening card + Daily Benefit card go here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_rounded, size: 52, color: AppColors.onDarkSecondary),
            const SizedBox(height: 16),
            Text(
              'Coming in Phase 5',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Continue Listening · Daily Benefit',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
