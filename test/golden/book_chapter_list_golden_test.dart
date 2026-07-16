@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/book_chapter_list_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';

import 'golden_config.dart';

/// Golden snapshots of the book chapter list — the surface where the marquee
/// visual bug shipped: chapter badges drew **Persian-shaped** 4/5/6/7 because
/// the numerals fell back to the UI font instead of the book face (194f7ef).
/// Every codepoint assertion passed; only a screenshot caught it. These pin the
/// pixels so the next such regression fails in CI, not in a user's hands.
///
/// See test/flutter_test_config.dart for font loading + the tolerant comparator,
/// and dart_test.yaml for why the `golden` tag is macOS-only.

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

// Enough chapters to exercise the badge numerals that actually broke: 4/5/6/7
// are the Persian-vs-Urdu divergent shapes.
const _book = BookContent(
  title: 'كتاب التوحيد',
  author: 'الشيخ محمد بن عبد الوهاب',
  chapters: [
    BookChapter(id: 'ch-01', number: 1, title: 'باب فضل التوحيد', text: 'x'),
    BookChapter(id: 'ch-04', number: 4, title: 'باب الدعاء إلى شهادة', text: 'x'),
    BookChapter(id: 'ch-05', number: 5, title: 'باب تفسير التوحيد', text: 'x'),
    BookChapter(id: 'ch-06', number: 6, title: 'باب من الشرك لبس الحلقة', text: 'x'),
    BookChapter(id: 'ch-07', number: 7, title: 'باب ما جاء في الرقى', text: 'x'),
  ],
);

Widget _app({
  required SeriesConfig series,
  required ThemeData theme,
  required Locale chrome,
}) {
  final bookProvider = BookProvider()..setBookForTest(_book);
  final seriesProvider = SeriesProvider()
    ..load(false)
    ..setCurrentSeriesForTest(series);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: bookProvider),
      ChangeNotifierProvider.value(value: seriesProvider),
    ],
    // `locale:` drives text direction: the Global*Localizations delegates set
    // Directionality from the locale (RTL for ar/ur), so this reproduces the
    // real app's chrome direction — the axis the RTL-mirroring bugs live on.
    child: MaterialApp.router(
      theme: theme,
      locale: chrome,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/book',
        routes: [
          GoRoute(
            path: '/book',
            builder: (_, __) => const BookChapterListScreen(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(configureGoldens);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  Future<void> pumpAt(
    WidgetTester tester, {
    required SeriesConfig series,
    required ThemeData theme,
    required Locale chrome,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(series: series, theme: theme, chrome: chrome));
    await tester.pumpAndSettle();
  }

  // The Urdu edition ships English (LTR) chrome by default (ADR-0002): badges on
  // the leading (left) edge, Urdu-face numerals.
  testWidgets('Urdu edition, English chrome — light', (tester) async {
    await pumpAt(tester,
        series: SeriesConfig.legacyUrduFallback,
        theme: AppTheme.light,
        chrome: const Locale('en'),);
    await expectLater(
      find.byType(BookChapterListScreen),
      matchesGoldenFile('goldens/book_chapter_list.urdu.light.png'),
    );
  });

  testWidgets('Urdu edition, English chrome — dark', (tester) async {
    await pumpAt(tester,
        series: SeriesConfig.legacyUrduFallback,
        theme: AppTheme.dark,
        chrome: const Locale('en'),);
    await expectLater(
      find.byType(BookChapterListScreen),
      matchesGoldenFile('goldens/book_chapter_list.urdu.dark.png'),
    );
  });

  // The Arabic edition ships Arabic (RTL) chrome: the whole layout mirrors —
  // badges move to the right edge. This is the direction the mirroring bugs
  // (3ae852d, 54f2d48, f6b4ade) live on, previously unguarded.
  testWidgets('Arabic edition, Arabic chrome (RTL) — light', (tester) async {
    await pumpAt(tester,
        series: _arabicSeries,
        theme: AppTheme.light,
        chrome: const Locale('ar'),);
    await expectLater(
      find.byType(BookChapterListScreen),
      matchesGoldenFile('goldens/book_chapter_list.arabic.light.png'),
    );
  });
}
