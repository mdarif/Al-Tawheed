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

Widget _wrap(SeriesProvider series) {
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: series)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
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

  testWidgets('opens with Saved, Settings and About entries', (tester) async {
    await tester.pumpWidget(_wrap(SeriesProvider()));
    await _openMenu(tester);

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('selecting Saved pushes /bookmarks', (tester) async {
    await tester.pumpWidget(_wrap(SeriesProvider()));
    await _openMenu(tester);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('BOOKMARKS PAGE'), findsOneWidget);
  });

  testWidgets('selecting Settings pushes /settings', (tester) async {
    await tester.pumpWidget(_wrap(SeriesProvider()));
    await _openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS PAGE'), findsOneWidget);
  });

  testWidgets('selecting About pushes /about', (tester) async {
    await tester.pumpWidget(_wrap(SeriesProvider()));
    await _openMenu(tester);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('ABOUT PAGE'), findsOneWidget);
  });

  testWidgets('shows Arabic labels for the Arabic series', (tester) async {
    final series = SeriesProvider()..setCurrentSeriesForTest(_arabicSeries);
    await tester.pumpWidget(_wrap(series));
    await _openMenu(tester);

    // Series-aware chrome: Arabic labels regardless of UI language.
    expect(find.text(arabicL10n.saved), findsOneWidget);
    expect(find.text(arabicL10n.tabSettings), findsOneWidget);
    expect(find.text(arabicL10n.settingsAbout), findsOneWidget);
  });
}
