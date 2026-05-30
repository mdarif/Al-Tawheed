import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/widgets/mini_player.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // MiniPlayer sits above the navigation bar and persists across all tabs
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _selectedIndex(context),
            onDestinationSelected: (i) => _navigate(context, i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.headphones_outlined),
                selectedIcon: Icon(Icons.headphones_rounded),
                label: 'Lectures',
              ),
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_outline_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: 'Saved',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/lectures')) return 0;
    if (path.startsWith('/home')) return 1;
    if (path.startsWith('/bookmarks')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/lectures');
      case 1:
        context.go('/home');
      case 2:
        context.go('/bookmarks');
      case 3:
        context.go('/settings');
    }
  }
}
