import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/app_overflow_menu.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizahullah'},
);

Widget _wrap(SeriesProvider series, {Locale? locale}) {
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: series)],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/host',
        routes: [
          GoRoute(
            path: '/host',
            builder: (_, __) => Scaffold(
              appBar: AppBar(actions: const [AppOverflowMenu()]),
            ),
          ),
          GoRoute(
            path: '/bookmarks',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('BOOKMARKS PAGE'))),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('SETTINGS PAGE'))),
          ),
          GoRoute(
            path: '/about',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('ABOUT PAGE'))),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert_rounded));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens with Bookmarks and About entries', (tester) async {
    await tester.pumpWidget(_wrap(SeriesProvider()));
    await _openMenu(tester);

    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    // Settings has its own bottom-nav tab (last) and is deliberately NOT
    // duplicated in the overflow menu.
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('selecting Bookmarks pushes /bookmarks', (tester) async {
    await tester.pumpWidget(_wrap(SeriesProvider()));
    await _openMenu(tester);
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();

    expect(find.text('BOOKMARKS PAGE'), findsOneWidget);
  });

  testWidgets('selecting About pushes /about', (tester) async {
    await tester.pumpWidget(_wrap(SeriesProvider()));
    await _openMenu(tester);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('ABOUT PAGE'), findsOneWidget);
  });

  testWidgets('shows Arabic labels for the Arabic series under Arabic UI',
      (tester) async {
    final series = SeriesProvider()..setCurrentSeriesForTest(_arabicSeries);
    await tester.pumpWidget(_wrap(series, locale: const Locale('ar')));
    await _openMenu(tester);

    // Chrome follows the UI locale (ar) — independent of the content edition.
    expect(find.text(arabicL10n.saved), findsOneWidget);
    expect(find.text(arabicL10n.settingsAbout), findsOneWidget);
  });
}
