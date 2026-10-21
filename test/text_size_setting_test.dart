import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/settings/text_size_setting.dart';

const _urdu = SeriesConfig(
  id: 'tawheed-ur',
  catalogUrl: 'https://example.com/tawheed-ur/catalog.json',
  storagePrefix: '',
  hasStudyMode: true,
  hasBook: true,
  language: 'ur',
  displayName: {'en': 'Urdu'},
  speakerName: {'en': 'Speaker'},
);

const _arabic = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Arabic'},
  speakerName: {'en': 'Speaker'},
);

// Chapter 1 opens with an Urdu lead-in, a braced verse, and a citation — the
// same shape as the real book. The intro chapter (number 0) must be skipped.
const _book = BookContent(
  title: 'كتاب التوحيد',
  author: 'الشيخ',
  chapters: [
    BookChapter(id: 'intro', number: 0, title: 'مقدمة', text: 'نص المقدمة'),
    BookChapter(
      id: 'ch-01',
      number: 1,
      title: 'الباب الأول',
      text:
          'ارشادِ باری تعالیٰ ہے: {وما خَلَقْتُ} [الذَّارِيَات: 56].\nثانی سطر',
    ),
    BookChapter(id: 'ch-02', number: 2, title: 'الثاني', text: 'نص آخر'),
  ],
);

// What the reader paints for chapter 1's first line: braces become the ornate
// verse brackets, digits follow the book's language (Urdu here).
const _expectedUrduPreview =
    'ارشادِ باری تعالیٰ ہے: \u{FD3F}وما خَلَقْتُ\u{FD3E} [الذَّارِيَات: ۵۶].';

Widget _harness({
  required Widget child,
  SeriesConfig series = _urdu,
  BookProvider? book,
  ReadingProvider? reading,
  Locale? locale,
  double textScale = 1,
  ThemeData? theme,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(
        value: reading ?? (ReadingProvider()..load()),
      ),
      ChangeNotifierProvider.value(
        value: book ?? (BookProvider()..setBookForTest(_book)),
      ),
      ChangeNotifierProvider.value(
        value: SeriesProvider()..setCurrentSeriesForTest(series),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

Text _preview(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(WidgetKeys.settingsTextSizePreview));

/// The preview's words, whether painted as one string or as styled runs.
String? _previewPlain(WidgetTester tester) {
  final t = _preview(tester);
  return t.data ?? t.textSpan?.toPlainText();
}

/// The preview's styled runs (empty when it is painted as a single string).
List<TextSpan> _previewRuns(WidgetTester tester) =>
    (_preview(tester).textSpan as TextSpan?)
        ?.children
        ?.whereType<TextSpan>()
        .toList() ??
    const [];

TextSpan _runContaining(WidgetTester tester, String needle) =>
    _previewRuns(tester).firstWhere(
      (r) => r.text?.contains(needle) ?? false,
      orElse: () => const TextSpan(text: '<no such run>'),
    );

String _valueText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(WidgetKeys.settingsTextSizeValue),
        matching: find.byType(Text),
      ),
    )
    .data!;

IconButton _button(WidgetTester tester, Key key) =>
    tester.widget<IconButton>(find.byKey(key));

Slider _slider(WidgetTester tester) =>
    tester.widget<Slider>(find.byKey(WidgetKeys.settingsTextSizeSlider));

/// The semantics node the slider itself exposes (the key's own node is a
/// merged wrapper around it).
SemanticsNode _sliderNode(WidgetTester tester) {
  SemanticsNode? found;
  bool visit(SemanticsNode n) {
    // ignore: deprecated_member_use
    if (n.hasFlag(SemanticsFlag.isSlider)) {
      found = n;
      return false;
    }
    n.visitChildren(visit);
    return found == null;
  }

  visit(tester.getSemantics(find.byKey(WidgetKeys.settingsTextSizeSlider)));
  return found!;
}

double _contrast(Color a, Color b) {
  final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('TextSizeSetting — slider', () {
    testWidgets('is an A – slider – A row, not the old −/+ outlined pair',
        (tester) async {
      await tester.pumpWidget(_harness(child: const TextSizeSetting()));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.settingsTextSizeSlider), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('A'), findsNWidgets(2));
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      // Left to right (LTR): small A, the slider, large A.
      final small = tester.getCenter(
        find.byKey(WidgetKeys.settingsTextSizeDecrease),
      );
      final track = tester.getCenter(
        find.byKey(WidgetKeys.settingsTextSizeSlider),
      );
      final large = tester.getCenter(
        find.byKey(WidgetKeys.settingsTextSizeIncrease),
      );
      expect(small.dx, lessThan(track.dx));
      expect(track.dx, lessThan(large.dx));
      // The glyphs differ in size: the small one really is the smaller.
      final glyphs = tester.widgetList<Text>(find.text('A')).toList();
      expect(
        glyphs.first.style!.fontSize,
        lessThan(glyphs.last.style!.fontSize!),
      );
    });

    testWidgets('spans 14–32 in 2pt notches and shows the provider value',
        (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      expect(_slider(tester).min, 14);
      expect(_slider(tester).max, 32);
      expect(_slider(tester).divisions, 9);
      expect(_slider(tester).value, 20);

      reading.setBookFontSizeLive(28);
      await tester.pump();
      expect(_slider(tester).value, 28);
    });

    testWidgets('dragging resizes live and persists only when the drag ends',
        (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();
      expect(PreferencesService.instance.bookFontSize, 20.0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(WidgetKeys.settingsTextSizeSlider)),
      );
      await gesture.moveBy(const Offset(400, 0));
      await tester.pump();

      // Live: the value, label and preview follow the finger…
      expect(reading.bookFontSize, 32.0);
      expect(_valueText(tester), '32');
      expect(_preview(tester).style?.fontSize, 32.0);
      // …but nothing is written to disk until the finger lifts.
      expect(PreferencesService.instance.bookFontSize, 20.0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 32.0);
      expect(PreferencesService.instance.bookFontSize, 32.0);
    });

    testWidgets('a tap on the track jumps to that notch and persists',
        (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(
        find.byKey(WidgetKeys.settingsTextSizeSlider),
      );
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await tester.pumpAndSettle();

      expect(reading.bookFontSize, 32.0);
      expect(PreferencesService.instance.bookFontSize, 32.0);
    });

    testWidgets('screen-reader adjust (increase / decrease) persists too',
        (tester) async {
      final handle = tester.ensureSemantics();
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      void adjust(SemanticsAction action) {
        final node = _sliderNode(tester);
        node.owner!.performAction(node.id, action);
      }

      adjust(SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 22.0);
      expect(PreferencesService.instance.bookFontSize, 22.0);

      adjust(SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 20.0);
      expect(PreferencesService.instance.bookFontSize, 20.0);
      handle.dispose();
    });

    testWidgets('announces the localized size to screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(locale: const Locale('ar'), child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      final node = _sliderNode(tester);
      expect(node.value, contains('٢٠'));
      handle.dispose();
    });

    // Material convention: the control mirrors with the chrome, so the
    // "small" end is at the start (right in RTL) and the track fills from the
    // start. Dragging toward the end (left in RTL) makes the text bigger.
    testWidgets('mirrors in RTL: small A at the start (right), drag left grows',
        (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(
          reading: reading,
          locale: const Locale('ar'),
          child: const TextSizeSetting(),
        ),
      );
      await tester.pumpAndSettle();

      final small = tester.getCenter(
        find.byKey(WidgetKeys.settingsTextSizeDecrease),
      );
      final large = tester.getCenter(
        find.byKey(WidgetKeys.settingsTextSizeIncrease),
      );
      expect(small.dx, greaterThan(large.dx));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(WidgetKeys.settingsTextSizeSlider)),
      );
      await gesture.moveBy(const Offset(-400, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 32.0);
    });

    for (final dark in [false, true]) {
      testWidgets(
          'active track and thumb are the brand colour, with contrast, in '
          '${dark ? 'dark' : 'light'} theme', (tester) async {
        await tester.pumpWidget(
          _harness(
            theme: dark ? AppTheme.dark : AppTheme.light,
            child: const TextSizeSetting(),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(
          find.byKey(WidgetKeys.settingsTextSizeSlider),
        );
        final slider = SliderTheme.of(context);
        final surface = Theme.of(context).colorScheme.surface;
        // Brand gold; in the light theme its darker tone, so it clears 3:1.
        final scheme = Theme.of(context).colorScheme;
        final brand = dark ? scheme.primary : scheme.secondary;
        expect(slider.activeTrackColor, brand);
        expect(slider.thumbColor, brand);
        // WCAG 1.4.11: the parts that carry the value need 3:1 on the card.
        expect(_contrast(slider.activeTrackColor!, surface), greaterThan(3));
        expect(_contrast(slider.thumbColor!, surface), greaterThan(3));
        // The unfilled rail must still be visible against the card.
        expect(
          _contrast(slider.inactiveTrackColor!, surface),
          greaterThan(1.3),
        );
      });
    }
  });

  group('TextSizeSetting — A buttons', () {
    testWidgets('shows the title, the current size and both A buttons',
        (tester) async {
      await tester.pumpWidget(_harness(child: const TextSizeSetting()));
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);
      expect(_valueText(tester), '20');
      expect(find.byTooltip('Smaller text'), findsOneWidget);
      expect(find.byTooltip('Larger text'), findsOneWidget);
    });

    testWidgets('the value sits at the end of the title row, above the slider',
        (tester) async {
      await tester.pumpWidget(_harness(child: const TextSizeSetting()));
      await tester.pumpAndSettle();

      final title = tester.getRect(find.text('Text size'));
      final value = tester.getRect(
        find.byKey(WidgetKeys.settingsTextSizeValue),
      );
      final slider = tester.getRect(
        find.byKey(WidgetKeys.settingsTextSizeSlider),
      );
      expect(value.left, greaterThan(title.right));
      expect(value.center.dy, closeTo(title.center.dy, 12));
      expect(slider.top, greaterThanOrEqualTo(value.bottom - 1));
    });

    testWidgets('+ and − move the size by 2pt and persist it', (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeIncrease));
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 22.0);
      expect(_valueText(tester), '22');
      expect(PreferencesService.instance.bookFontSize, 22.0);

      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeDecrease));
      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeDecrease));
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 18.0);
      expect(_valueText(tester), '18');
      expect(PreferencesService.instance.bookFontSize, 18.0);
    });

    testWidgets('+ is disabled at the 32pt maximum, − at the 14pt minimum',
        (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      await reading.setBookFontSize(32);
      await tester.pumpAndSettle();
      expect(
        _button(tester, WidgetKeys.settingsTextSizeIncrease).onPressed,
        isNull,
      );
      expect(
        _button(tester, WidgetKeys.settingsTextSizeDecrease).onPressed,
        isNotNull,
      );
      await tester.tap(
        find.byKey(WidgetKeys.settingsTextSizeIncrease),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 32.0);

      await reading.setBookFontSize(14);
      await tester.pumpAndSettle();
      expect(
        _button(tester, WidgetKeys.settingsTextSizeDecrease).onPressed,
        isNull,
      );
      expect(
        _button(tester, WidgetKeys.settingsTextSizeIncrease).onPressed,
        isNotNull,
      );
      await tester.tap(
        find.byKey(WidgetKeys.settingsTextSizeDecrease),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 14.0);
    });

    testWidgets('an odd size steps onto the bound instead of past it',
        (tester) async {
      final reading = ReadingProvider()..load();
      await reading.setBookFontSize(31);
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      // 31 is still below the max, so + is live; 31 + 2 clamps to 32.
      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeIncrease));
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 32.0);
    });

    testWidgets('both buttons are at least 48dp square', (tester) async {
      await tester.pumpWidget(_harness(child: const TextSizeSetting()));
      await tester.pumpAndSettle();

      for (final key in [
        WidgetKeys.settingsTextSizeDecrease,
        WidgetKeys.settingsTextSizeIncrease,
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48), reason: '$key');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$key');
      }
    });

    testWidgets('the value is a live region so a change is announced',
        (tester) async {
      final handle = tester.ensureSemantics();
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      SemanticsNode node() =>
          tester.getSemantics(find.byKey(WidgetKeys.settingsTextSizeValue));
      // ignore: deprecated_member_use
      expect(node().hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      expect(node().label, contains('20'));

      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeIncrease));
      await tester.pumpAndSettle();
      expect(node().label, contains('22'));
      handle.dispose();
    });

    testWidgets('the step buttons expose their labels to screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(child: const TextSizeSetting()));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byTooltip('Smaller text')).tooltip,
        equals('Smaller text'),
      );
      expect(
        tester.getSemantics(find.byTooltip('Larger text')).tooltip,
        equals('Larger text'),
      );
      handle.dispose();
    });

    testWidgets('follows a change made elsewhere (pinch) through the provider',
        (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      reading.setBookFontSizeLive(27); // what the reader's pinch writes
      await tester.pump();

      expect(_valueText(tester), '27');
      expect(_preview(tester).style?.fontSize, 27.0);
    });

    testWidgets('two instances on one provider stay in step (Settings + sheet)',
        (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(
          reading: reading,
          child: const Column(
            children: [
              TextSizeSetting(key: ValueKey('a')),
              TextSizeSetting(key: ValueKey('b')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('a')),
          matching: find.byKey(WidgetKeys.settingsTextSizeIncrease),
        ),
      );
      await tester.pumpAndSettle();

      final values = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(WidgetKeys.settingsTextSizeValue),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data);
      expect(values, ['22', '22']);
    });
  });

  group('TextSizeSetting — book preview', () {
    testWidgets("shows chapter 1's opening line in the book's own font",
        (tester) async {
      await tester.pumpWidget(_harness(child: const TextSizeSetting()));
      await tester.pumpAndSettle();

      final preview = _preview(tester);
      expect(_previewPlain(tester), _expectedUrduPreview);
      expect(preview.style?.fontFamily, 'NotoNastaliqUrdu');
      expect(preview.textDirection, TextDirection.rtl);
      // Nastaliq needs generous leading (a11y floor: 1.8–2.1).
      expect(preview.style?.height, inInclusiveRange(1.8, 2.1));
    });

    testWidgets('the Arabic edition previews in Naskh with Arabic digits',
        (tester) async {
      await tester.pumpWidget(
        _harness(series: _arabic, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      final preview = _preview(tester);
      expect(preview.style?.fontFamily, 'NotoNaskhArabic');
      expect(preview.textDirection, TextDirection.rtl);
      expect(_previewPlain(tester), contains('٥٦'));
      expect(preview.style?.height, inInclusiveRange(1.8, 2.1));
    });

    testWidgets('the preview tracks the size', (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(
        _harness(reading: reading, child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();
      expect(_preview(tester).style?.fontSize, 20.0);

      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeIncrease));
      await tester.pumpAndSettle();
      expect(_preview(tester).style?.fontSize, 22.0);
    });

    // The reader paints Urdu runs in Nastaliq at 0.78× and Arabic runs (the
    // āyah, citations) in Naskh at full size, on the same line. A preview
    // that drew the whole line at one size would show Urdu larger than the
    // reader will.
    testWidgets('sizes each run by its script, exactly as the reader does',
        (tester) async {
      await tester.pumpWidget(_harness(child: const TextSizeSetting()));
      await tester.pumpAndSettle();

      final urdu = _runContaining(tester, 'ارشادِ');
      expect(urdu.style?.fontFamily, 'NotoNastaliqUrdu');
      expect(urdu.style?.fontSize, closeTo(20 * 0.78, 1e-9));

      final ayah = _runContaining(tester, 'وما');
      expect(ayah.style?.fontFamily, 'NotoNaskhArabic');
      expect(ayah.style?.fontSize, 20.0);

      final citation = _runContaining(tester, 'الذَّارِيَات');
      expect(citation.style?.fontFamily, 'NotoNaskhArabic');
      expect(citation.style?.fontSize, 20.0);

      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeIncrease));
      await tester.pumpAndSettle();
      expect(
        _runContaining(tester, 'ارشادِ').style?.fontSize,
        closeTo(22 * 0.78, 1e-9),
      );
      expect(_runContaining(tester, 'وما').style?.fontSize, 22.0);
    });

    testWidgets('mentions that pinch also works', (tester) async {
      await tester.pumpWidget(_harness(child: const TextSizeSetting()));
      await tester.pumpAndSettle();

      expect(find.textContaining('pinch'), findsOneWidget);
    });

    testWidgets('no preview (but a working stepper) until the book is loaded',
        (tester) async {
      final reading = ReadingProvider()..load();
      final book = BookProvider()..setLoadingForTest();
      await tester.pumpWidget(
        _harness(
          reading: reading,
          book: book,
          child: const TextSizeSetting(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.settingsTextSizePreview), findsNothing);
      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeIncrease));
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 22.0);
    });

    testWidgets('loads the active edition\'s bundled book when none is loaded',
        (tester) async {
      final book = BookProvider(); // idle: nothing has opened the Book yet
      await tester.pumpWidget(
        _harness(book: book, child: const TextSizeSetting()),
      );
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && book.status != BookStatus.loaded; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pumpAndSettle();

      expect(book.status, BookStatus.loaded);
      final real = _readRealBook('ur');
      expect(
        _previewPlain(tester),
        bookPreviewText(real.chapters.first, 'ur'),
      );
    });
  });

  // The preview is scripture. It must be the book's own words — never invented
  // or translated — so check it against the shipped JSON, undoing only the
  // display transforms the reader applies (ornate brackets, script digits).
  group('bookPreviewText — verbatim from the bundled book', () {
    for (final edition in ['ar', 'ur']) {
      test('$edition: equals chapter 1\'s first line up to display marks', () {
        final chapter = _readRealBook(edition).chapters.first;
        expect(chapter.number, 1);
        final firstLine = chapter.text
            .split('\n')
            .map((l) => l.trim())
            .firstWhere((l) => l.isNotEmpty);

        final preview = bookPreviewText(chapter, edition);

        expect(_undoDisplayMarks(preview), firstLine);
        expect(preview, isNotEmpty);
        expect(preview.contains('\n'), isFalse);
      });
    }

    test('skips an unnumbered intro and blank lines', () {
      expect(
        bookPreviewText(_book.chapters[1], 'ur'),
        _expectedUrduPreview,
      );
      const blankLead = BookChapter(
        id: 'x',
        number: 1,
        title: '',
        text: '\n  \nأول سطر\nثان',
      );
      expect(bookPreviewText(blankLead, 'ar'), 'أول سطر');
    });
  });

  group('TextSizeSetting — RTL and 2× text', () {
    for (final locale in [
      const Locale('ar'),
      const Locale('ur'),
      const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
    ]) {
      testWidgets('lays out without overflow in $locale at 2.0 scale',
          (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _harness(
            locale: locale,
            textScale: 2,
            child: const TextSizeSetting(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final key in [
          WidgetKeys.settingsTextSizeDecrease,
          WidgetKeys.settingsTextSizeIncrease,
        ]) {
          final rect = tester.getRect(find.byKey(key));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
        }
        // The slider keeps a usable track between the two A buttons.
        final track = tester.getRect(
          find.byKey(WidgetKeys.settingsTextSizeSlider),
        );
        expect(track.width, greaterThan(120));
        expect(track.left, greaterThanOrEqualTo(0));
        expect(track.right, lessThanOrEqualTo(360));
      });
    }

    testWidgets('chrome digits follow the chrome locale', (tester) async {
      await tester.pumpWidget(
        _harness(locale: const Locale('ar'), child: const TextSizeSetting()),
      );
      await tester.pumpAndSettle();

      expect(_valueText(tester), '٢٠');
    });
  });

  group('showTextSizeSheet', () {
    Widget opener({
      double scale = 1,
      Locale? locale,
      ReadingProvider? reading,
    }) =>
        _harness(
          reading: reading,
          locale: locale,
          textScale: scale,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTextSizeSheet(context),
              child: const Text('open'),
            ),
          ),
        );

    testWidgets('opens a sheet whose controls write the shared provider',
        (tester) async {
      final reading = ReadingProvider()..load();
      await tester.pumpWidget(opener(reading: reading));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(TextSizeSetting), findsOneWidget);
      expect(find.byKey(WidgetKeys.settingsTextSizeSlider), findsOneWidget);
      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeIncrease));
      await tester.pumpAndSettle();

      expect(reading.bookFontSize, 22.0);
      expect(PreferencesService.instance.bookFontSize, 22.0);

      await tester.drag(
        find.byKey(WidgetKeys.settingsTextSizeSlider),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 14.0);
      expect(PreferencesService.instance.bookFontSize, 14.0);
    });

    for (final locale in [const Locale('ar'), const Locale('ur')]) {
      testWidgets('fits in $locale at 2.0 scale on a small phone',
          (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(opener(scale: 2, locale: locale));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TextSizeSetting), findsOneWidget);
        expect(
          tester.getSize(find.byKey(WidgetKeys.settingsTextSizeIncrease)).width,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byKey(WidgetKeys.settingsTextSizeSlider)).width,
          greaterThan(120),
        );
      });
    }
  });
}

BookContent _readRealBook(String edition) => BookContent.fromJson(
      jsonDecode(
        File('assets/content/book_tawheed-$edition.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );

/// Reverses the reader's display-only substitutions so a preview can be
/// compared against the raw source line.
String _undoDisplayMarks(String s) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const extended = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final a = arabicIndic.indexOf(ch);
    final e = extended.indexOf(ch);
    if (ch == '\u{FD3F}') {
      buffer.write('{');
    } else if (ch == '\u{FD3E}') {
      buffer.write('}');
    } else if (a >= 0) {
      buffer.write(a);
    } else if (e >= 0) {
      buffer.write(e);
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}
