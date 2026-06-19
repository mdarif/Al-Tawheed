import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/widgets/all_lectures_complete_listener.dart';
import 'package:myapp/widgets/mini_player.dart';
import 'package:myapp/widgets/offline_status_banner.dart';

enum _Tab { lectures, book, home, study, settings }

// Arabic bottom-nav labels shown for the Arabic series, independent of the
// app's UI-chrome language — mirrors the _arXxx pattern used elsewhere
// (home_screen.dart, player_screen.dart, choose_series_screen.dart).
const _arTabLectures = 'الدروس';
const _arTabBook = 'الكتاب';
const _arTabHome = 'الرئيسية';
const _arTabSettings = 'الإعدادات';

extension on _Tab {
  String get path => switch (this) {
        _Tab.lectures => '/lectures',
        _Tab.book => '/book',
        _Tab.home => '/home',
        _Tab.study => '/study',
        _Tab.settings => '/settings',
      };

  NavigationDestination destination(bool isRtl) => switch (this) {
        _Tab.lectures => NavigationDestination(
            icon: const Icon(Icons.headphones_outlined),
            selectedIcon: const Icon(Icons.headphones_rounded),
            label: isRtl ? _arTabLectures : 'Lectures',
          ),
        _Tab.book => NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book_rounded),
            label: isRtl ? _arTabBook : 'Book',
          ),
        _Tab.home => NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: isRtl ? _arTabHome : 'Home',
          ),
        _Tab.study => NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school_rounded),
            label: 'Study',
          ),
        _Tab.settings => NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: isRtl ? _arTabSettings : 'Settings',
          ),
      };
}

List<_Tab> _tabsFor(SeriesConfig series) => [
      _Tab.lectures,
      if (series.hasBook) _Tab.book,
      _Tab.home,
      if (series.hasStudyMode) _Tab.study,
      _Tab.settings,
    ];

class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final series = context.watch<SeriesProvider>().currentSeries;
    final tabs = _tabsFor(series);

    return AllLecturesCompleteListener(
      child: Scaffold(
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
              selectedIndex: _selectedIndex(context, tabs),
              onDestinationSelected: (i) => context.go(tabs[i].path),
              destinations: [
                for (final tab in tabs) tab.destination(series.isRtl),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _selectedIndex(BuildContext context, List<_Tab> tabs) {
    final path = GoRouterState.of(context).uri.path;
    final index = tabs.indexWhere((tab) => path.startsWith(tab.path));
    return index == -1 ? 0 : index;
  }
}
