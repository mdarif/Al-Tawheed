import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/mini_player.dart';
import 'package:myapp/widgets/offline_status_banner.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasStudyMode =
        context.watch<SeriesProvider>().currentSeries.hasStudyMode;

    return Scaffold(
      body: Column(
        children: [
          const OfflineStatusBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _selectedIndex(context, hasStudyMode),
            onDestinationSelected: (i) => _navigate(context, i, hasStudyMode),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.headphones_outlined),
                selectedIcon: const Icon(Icons.headphones_rounded),
                label: l10n.tabLectures,
              ),
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l10n.tabHome,
              ),
              if (hasStudyMode)
                NavigationDestination(
                  icon: const Icon(Icons.school_outlined),
                  selectedIcon: const Icon(Icons.school_rounded),
                  label: l10n.tabStudyMode,
                ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: l10n.tabSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context, bool hasStudyMode) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/lectures')) return 0;
    if (path.startsWith('/home')) return 1;
    if (hasStudyMode && path.startsWith('/study')) return 2;
    if (path.startsWith('/settings')) return hasStudyMode ? 3 : 2;
    return 0;
  }

  void _navigate(BuildContext context, int index, bool hasStudyMode) {
    if (!hasStudyMode) {
      switch (index) {
        case 0:
          context.go('/lectures');
        case 1:
          context.go('/home');
        case 2:
          context.go('/settings');
      }
      return;
    }
    switch (index) {
      case 0:
        context.go('/lectures');
      case 1:
        context.go('/home');
      case 2:
        context.go('/study');
      case 3:
        context.go('/settings');
    }
  }
}
