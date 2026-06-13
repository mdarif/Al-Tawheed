import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaykh Salih Al-Fawzan'},
);

Widget _wrap({required SeriesProvider series, String initialLocation = '/lectures'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider(
        create: (ctx) => PlayerNotifier(
          TawheedAudioHandler(),
          ctx.read<ProgressProvider>(),
          ctx.read<DownloadsProvider>(),
          ctx.read<ConnectivityProvider>(),
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: initialLocation,
        routes: [
          ShellRoute(
            builder: (context, state, child) => ShellScreen(child: child),
            routes: [
              GoRoute(
                path: '/lectures',
                builder: (_, __) => const Scaffold(body: Center(child: Text('Lectures'))),
              ),
              GoRoute(
                path: '/home',
                builder: (_, __) => const Scaffold(body: Center(child: Text('Home'))),
              ),
              GoRoute(
                path: '/study',
                builder: (_, __) => const Scaffold(body: Center(child: Text('Study'))),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, __) => const Scaffold(body: Center(child: Text('Settings'))),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets('shows 4 tabs including Study for the Urdu (study-mode) series',
      (tester) async {
    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    // "Lectures" appears twice: the page body and the nav destination label.
    expect(find.text('Lectures'), findsNWidgets(2));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('shows 3 tabs without Study for a series with no study mode',
      (tester) async {
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.text('Lectures'), findsNWidgets(2));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Study'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });

  testWidgets('tapping Settings navigates correctly in the 3-tab layout',
      (tester) async {
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsNWidgets(2)); // tab label + page body
  });
}
