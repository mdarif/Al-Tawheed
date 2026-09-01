import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/navigation/series_navigation_policy.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/all_lectures_complete_listener.dart';
import 'package:myapp/widgets/mini_player.dart';
import 'package:myapp/widgets/offline_status_banner.dart';

const _kChromeAnim = Duration(milliseconds: 220);

extension on SeriesNavigationTab {
  /// StatefulShellRoute branch indexes are fixed at router construction, while
  /// the visible destinations vary by edition capability.
  int get branchIndex => switch (this) {
        SeriesNavigationTab.lectures => 0,
        SeriesNavigationTab.book => 1,
        SeriesNavigationTab.study => 2,
        SeriesNavigationTab.library => 3,
        SeriesNavigationTab.settings => 4,
      };

  NavigationDestination destination(AppLocalizations l10n) => switch (this) {
        SeriesNavigationTab.lectures => NavigationDestination(
            key: WidgetKeys.shellLecturesTab,
            icon: const Icon(Icons.headphones_outlined),
            selectedIcon: const Icon(Icons.headphones_rounded),
            label: l10n.tabLectures,
          ),
        SeriesNavigationTab.book => NavigationDestination(
            key: WidgetKeys.shellBookTab,
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book_rounded),
            label: l10n.tabBook,
          ),
        SeriesNavigationTab.study => NavigationDestination(
            key: WidgetKeys.shellStudyTab,
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school_rounded),
            label: l10n.tabStudyMode,
          ),
        SeriesNavigationTab.library => NavigationDestination(
            key: WidgetKeys.shellLibraryTab,
            icon: const Icon(Icons.collections_bookmark_outlined),
            selectedIcon: const Icon(Icons.collections_bookmark_rounded),
            label: l10n.tabLibrary,
          ),
        SeriesNavigationTab.settings => NavigationDestination(
            key: WidgetKeys.shellSettingsTab,
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.tabSettings,
          ),
      };
}

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const ShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final series = context.watch<SeriesProvider>().currentSeries;
    final chromeVisible = context.watch<ShellChromeProvider>().visible;
    final tabs = SeriesNavigationPolicy.tabsFor(series);
    final l10n = context.l10n;

    return PopScope<void>(
      // Each branch navigator gets first chance to pop its own stack. Once a
      // branch is at its root, Android Back returns to Lectures before it can
      // leave the app.
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: AllLecturesCompleteListener(
        child: Scaffold(
          body: Column(
            children: [
              const OfflineStatusBanner(),
              Expanded(child: navigationShell),
            ],
          ),
          extendBody: true,
          bottomNavigationBar: AnimatedSlide(
            offset: chromeVisible ? Offset.zero : const Offset(0, 1),
            duration: _kChromeAnim,
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                NavigationBar(
                  selectedIndex: _selectedIndex(tabs),
                  onDestinationSelected: (i) => navigationShell.goBranch(
                    tabs[i].branchIndex,
                    initialLocation:
                        tabs[i].branchIndex == navigationShell.currentIndex,
                  ),
                  destinations: [for (final tab in tabs) tab.destination(l10n)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _selectedIndex(List<SeriesNavigationTab> tabs) {
    final index = tabs.indexWhere(
      (tab) => tab.branchIndex == navigationShell.currentIndex,
    );
    return index == -1 ? 0 : index;
  }
}
