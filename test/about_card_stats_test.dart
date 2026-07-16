import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/settings/about_card.dart';

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
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          // The real About page hosts the card in a ListView, so vertical
          // growth scrolls — a scroll view here keeps the test faithful and
          // isolates the actual §8 risk: HORIZONTAL overflow of the fixed
          // three-column stats Row.
          child: Scaffold(
            body: SingleChildScrollView(
              child: AboutCard(
                about: AppConfigModel.defaults.about,
                catalog: catalog,
              ),
            ),
          ),
        ),
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
    testWidgets('Arabic chrome: ٢٣ س ١٩ د', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(
        _wrap(
          catalog: _catalog(),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('٢٣ س ١٩ د'), findsOneWidget);
      expect(find.text('٩١'), findsOneWidget);
      expect(find.text('المدة'), findsOneWidget);
    });

    testWidgets('Urdu chrome spells the units out', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(
        _wrap(
          catalog: _catalog(),
          locale: const Locale('ur'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('۲۳ گھنٹے ۱۹ منٹ'), findsOneWidget);
      expect(find.text('۹۱'), findsOneWidget);
    });

    // The widest string the app can produce: three-digit hours, spelled units.
    testWidgets('a three-digit hour count still fits in Urdu', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(
        _wrap(
          catalog: _catalog(totalDurationSeconds: 999 * 3600 + 59 * 60),
          locale: const Locale('ur'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('۹۹۹ گھنٹے ۵۹ منٹ'), findsOneWidget);
    });

    // The Urdu edition's default. Nothing about it changed for the Arabic work.
    testWidgets('English chrome keeps Western digits', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(_wrap(catalog: _catalog()));
      await tester.pumpAndSettle();

      expect(find.text('23h 19m'), findsOneWidget);
    });

    testWidgets('under an hour, only minutes are shown', (tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(
        _wrap(
          catalog: _catalog(totalDurationSeconds: 2400),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('٤٠ د'), findsOneWidget);
    });
  });

  // test-plan §8 — dynamic type. The existing tests pin the narrow WIDTH but
  // not the text scale; a user at the OS accessibility max (~2.0) is where the
  // three fixed columns of spelled-out Urdu units are most likely to overflow.
  // A RenderFlex overflow throws and fails the test on its own — no explicit
  // assertion needed beyond "it rendered".
  group('About stats strip — scales without overflow', () {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Urdu, widest duration, textScaler $scale', (tester) async {
        useNarrowPhone(tester);
        await tester.pumpWidget(
          _wrap(
            catalog: _catalog(totalDurationSeconds: 999 * 3600 + 59 * 60),
            locale: const Locale('ur'),
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('۹۹۹ گھنٹے ۵۹ منٹ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
