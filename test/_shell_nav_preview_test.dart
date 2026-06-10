import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/theme/app_theme.dart';

Widget _navBar(AppLocalizations l10n) {
  return NavigationBar(
    selectedIndex: 2,
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
  );
}

void main() {
  testWidgets('preview bottom nav EN + UR', (tester) async {
    tester.view.physicalSize = const Size(1179, 600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            bottomNavigationBar: _navBar(AppLocalizations.of(context)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NavigationBar),
      matchesGoldenFile('shell_nav_en.png'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ur'),
        home: Builder(
          builder: (context) => Scaffold(
            bottomNavigationBar: _navBar(AppLocalizations.of(context)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NavigationBar),
      matchesGoldenFile('shell_nav_ur.png'),
    );
  });
}
