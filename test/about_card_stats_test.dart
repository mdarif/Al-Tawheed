import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/settings/about_card.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan'},
);

/// A catalog with **no chapters** — that is what makes the stats strip render
/// its Duration column instead of a class count.
Catalog _catalog({int totalDurationSeconds = 83940}) => Catalog.fromJson({
      'version': 1,
      'book': {
        'id': 'b',
        'title': {'en': 'Kitab at-Tawheed'},
        'titleArabic': 'كتاب التوحيد',
        'speaker': {'en': 'Speaker'},
        'totalDurationSeconds': totalDurationSeconds,
        'lectureCount': 91,
      },
      'chapters': <Map<String, dynamic>>[],
      'lectures': <Map<String, dynamic>>[],
    });

Widget _wrap({
  required Catalog catalog,
  Locale? locale,
  SeriesConfig? series,
}) {
  final seriesProvider = SeriesProvider()..load(false);
  if (series != null) seriesProvider.setCurrentSeriesForTest(series);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider.value(value: seriesProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AboutCard(about: AppConfigModel.defaults.about, catalog: catalog),
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

  // The default 800x600 test surface is far wider than a phone and would hide
  // exactly the overflow these tests exist to catch. Pin a narrow, realistic
  // one (iPhone SE class, the tightest we support).
  void useNarrowPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // The stats strip is three fixed columns in a Row; a long duration string has
  // nowhere to go, and Urdu spells the units out ("گھنٹے"/"منٹ") where English
  // uses "h"/"m". A RenderFlex overflow fails the test on its own — these pin
  // the widest realistic values so we find out here, not in a screenshot.
  group('About stats strip — duration fits', () {
    testWidgets('Arabic chrome, Arabic edition: ٢٣ س ١٩ د', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(_wrap(
        catalog: _catalog(),
        locale: const Locale('ar'),
        series: _arabicSeries,
      ),);
      await tester.pumpAndSettle();

      expect(find.text('٢٣ س ١٩ د'), findsOneWidget);
      expect(find.text('٩١'), findsOneWidget);
      expect(find.text('المدة'), findsOneWidget);
    });

    testWidgets('Urdu chrome on the Urdu edition spells the units out',
        (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(_wrap(
        catalog: _catalog(),
        locale: const Locale('ur'),
      ),);
      await tester.pumpAndSettle();

      expect(find.text('۲۳ گھنٹے ۱۹ منٹ'), findsOneWidget);
      expect(find.text('۹۱'), findsOneWidget);
    });

    // The widest string the app can produce: three-digit hours, spelled units.
    testWidgets('a three-digit hour count still fits in Urdu', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(_wrap(
        catalog: _catalog(totalDurationSeconds: 999 * 3600 + 59 * 60),
        locale: const Locale('ur'),
      ),);
      await tester.pumpAndSettle();

      expect(find.text('۹۹۹ گھنٹے ۵۹ منٹ'), findsOneWidget);
    });

    testWidgets('English chrome keeps the compact form', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(_wrap(catalog: _catalog()));
      await tester.pumpAndSettle();

      // Urdu edition by default → Urdu digits, English words.
      expect(find.text('۲۳h ۱۹m'), findsOneWidget);
    });

    testWidgets('under an hour, only minutes are shown', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(_wrap(
        catalog: _catalog(totalDurationSeconds: 2400),
        locale: const Locale('ar'),
        series: _arabicSeries,
      ),);
      await tester.pumpAndSettle();

      expect(find.text('٤٠ د'), findsOneWidget);
    });
  });
}
