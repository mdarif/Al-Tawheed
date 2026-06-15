// Widget tests for Al-Tawheed V2.
// MyApp requires async AudioService init, so these tests target
// individual screens wrapped in a minimal MaterialApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

Widget _wrap(Widget child,
    {ThemeMode themeMode = ThemeMode.dark, SeriesConfig? series}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ChangeNotifierProvider(create: (_) {
        final provider = SeriesProvider()..load(false);
        if (series != null) provider.setCurrentSeriesForTest(series);
        return provider;
      }),
    ],
    child: Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
  });

  group('Widget Tests - Sharah Kitab At-Tawheed', () {
    testWidgets('App starts and displays welcome screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(WelcomeScreen()));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Welcome screen has correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(WelcomeScreen()));
      expect(find.textContaining('Kitab al-Tawheed'), findsOneWidget);
    });

    testWidgets('Welcome screen has START LISTENING button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(WelcomeScreen()));
      expect(find.text('START LISTENING'), findsOneWidget);
    });

    testWidgets(
        'Welcome screen shows the Arabic call-to-action for the Arabic series',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(WelcomeScreen(), series: _arabicSeries));
      expect(find.text('ابدأ الاستماع'), findsOneWidget);
      expect(find.text('START LISTENING'), findsNothing);
    });
  });
}
