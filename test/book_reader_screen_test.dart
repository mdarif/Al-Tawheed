import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/book_reader_screen.dart';
import 'package:myapp/theme/app_semantic_colors.dart';
import 'package:myapp/theme/app_theme.dart';

const _testBook = BookContent(
  title: 'كتاب التوحيد',
  author: 'الشيخ محمد بن عبد الوهاب',
  chapters: [
    BookChapter(id: 'intro', number: 0, title: 'مقدمة', text: 'نص المقدمة'),
    BookChapter(
        id: 'ch-01', number: 1, title: 'الباب الأول', text: 'نص الباب الأول',),
    BookChapter(
        id: 'ch-02', number: 2, title: 'الباب الثاني', text: 'نص الباب الثاني',),
  ],
);

Widget _wrap(BookProvider book, String chapterId) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: book),
      ChangeNotifierProvider(create: (_) => ReadingProvider()),
      ChangeNotifierProvider(create: (_) => SeriesProvider()),
      // The chapter footer's "report a mistake" link reads the contact address
      // from here. Defaults carry one, so the link renders in these tests.
      ChangeNotifierProvider(create: (_) => AppConfigProvider()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/book/$chapterId',
        routes: [
          GoRoute(
            path: '/book/:chapterId',
            builder: (context, state) => BookReaderScreen(
              chapterId: state.pathParameters['chapterId']!,
            ),
          ),
        ],
      ),
    ),
  );
}

// Finds the styled span for [text] inside the reader's rendered Text.rich runs.
TextSpan? _spanFor(WidgetTester tester, String text) {
  TextSpan? found;
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final span = w.textSpan;
    if (span == null) continue;
    span.visitChildren((s) {
      if (s is TextSpan && s.text == text) found = s;
      return true;
    });
    if (found != null) return found;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('masāʾil heading', () {
    // The masail section is the author's own summary, distinct from the quoted
    // matn above it — it gets a rule + the brand colour.
    const masailBook = BookContent(
      title: 'کتاب التوحید',
      author: 'مصنف',
      chapters: [
        BookChapter(
          id: 'ch-01',
          number: 1,
          title: 'باب',
          text: 'متن کی سطر\n\n'
              'اس باب کے کچھ اہم مسائل:\n'
              'پہلا مسئلہ: پہلی بات۔',
        ),
        // Guard: a numbered ITEM that itself uses the plural مسائل mid-sentence
        // (this really happens in ch-01/ch-11 of the Urdu book). It must NOT be
        // mistaken for a heading, or a rule would land in the middle of the list.
        BookChapter(
          id: 'ch-02',
          number: 2,
          title: 'باب',
          text: 'اس باب کے کچھ اہم مسائل:\n'
              'نواں مسئلہ: مذکورہ آیتوں میں کئی مسائل بیان کیے گئے ہیں۔',
        ),
        // The print's longer heading variant (ch-06) must still be recognised.
        BookChapter(
          id: 'ch-03',
          number: 3,
          title: 'باب',
          text: 'متن\n\n'
              'اس باب میں کئی اہم ترین اور عظیم مسائل ہیں، جن میں سب سے اہم مندرجہ ذیل ہیں:\n'
              'پہلی بات۔',
        ),
      ],
    );

    testWidgets('is set off by a rule and rendered in the brand colour',
        (tester) async {
      final book = BookProvider()..setBookForTest(masailBook);
      await tester.pumpWidget(_wrap(book, 'ch-01'));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);

      final span = _spanFor(tester, 'اس باب کے کچھ اہم مسائل:');
      expect(span, isNotNull);
      expect(span!.style?.color, AppTheme.light.extension<AppSemanticColors>()!.brand);
      expect(span.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('a masʾala item using the word مسائل is NOT treated as one',
        (tester) async {
      final book = BookProvider()..setBookForTest(masailBook);
      await tester.pumpWidget(_wrap(book, 'ch-02'));
      await tester.pumpAndSettle();

      // Only the real heading gets a rule — not the item that mentions مسائل.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('recognises the print\'s longer heading variant',
        (tester) async {
      final book = BookProvider()..setBookForTest(masailBook);
      await tester.pumpWidget(_wrap(book, 'ch-03'));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('a chapter with no masāʾil gets no rule', (tester) async {
      final book = BookProvider()..setBookForTest(_testBook); // Arabic, matn-only
      await tester.pumpWidget(_wrap(book, 'ch-01'));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsNothing);
    });
  });

  group('chapter position indicator', () {
    // Long bab titles ellipsize in the app bar, so the title alone never tells
    // you where you are in the book.
    testWidgets('shows the current chapter and total', (tester) async {
      final book = BookProvider()..setBookForTest(_testBook);
      await tester.pumpWidget(_wrap(book, 'ch-01')); // 2nd of 3 chapters
      await tester.pumpAndSettle();

      // SeriesProvider defaults to the Urdu series here, so Urdu numerals.
      expect(find.text('۲ / ۳'), findsOneWidget);
    });

    testWidgets('tracks position as you move through the book',
        (tester) async {
      final book = BookProvider()..setBookForTest(_testBook);
      await tester.pumpWidget(_wrap(book, 'intro')); // 1st of 3
      await tester.pumpAndSettle();

      expect(find.text('۱ / ۳'), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      expect(find.text('۲ / ۳'), findsOneWidget);
    });
  });

  testWidgets('renders the chapter title and text', (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);

    await tester.pumpWidget(_wrap(book, 'ch-01'));
    await tester.pumpAndSettle();

    expect(find.text('الباب الأول'), findsOneWidget);
    expect(find.text('نص الباب الأول'), findsOneWidget);
  });

  testWidgets('prev button is disabled on the first chapter', (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);

    await tester.pumpWidget(_wrap(book, 'intro'));
    await tester.pumpAndSettle();

    final prevButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
    );
    expect(prevButton.onPressed, isNull);
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets('next button is disabled on the last chapter', (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);

    await tester.pumpWidget(_wrap(book, 'ch-02'));
    await tester.pumpAndSettle();

    final prevButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
    );
    expect(prevButton.onPressed, isNotNull);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('next button navigates to the next chapter without growing the stack',
      (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);

    await tester.pumpWidget(_wrap(book, 'ch-01'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    expect(find.text('الباب الثاني'), findsOneWidget);
    expect(find.text('نص الباب الثاني'), findsOneWidget);
  });

  testWidgets('swiping the page advances to the next chapter', (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);

    await tester.pumpWidget(_wrap(book, 'ch-01'));
    await tester.pumpAndSettle();

    expect(find.text('نص الباب الأول'), findsOneWidget);

    // reverse:true pager — a left-to-right (positive dx) fling turns to the
    // next chapter, matching RTL page-turn direction.
    await tester.fling(find.byType(PageView), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('الباب الثاني'), findsOneWidget); // app bar title updated
    expect(find.text('نص الباب الثاني'), findsOneWidget);
  });

  testWidgets('color key button opens the legend sheet', (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);

    await tester.pumpWidget(_wrap(book, 'ch-01'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    // English chrome (test wrap uses default/en locale) — legend labels show.
    expect(find.text('Color key'), findsOneWidget);
    expect(find.text("Qur'an verse"), findsOneWidget);
    expect(find.text('Reference (surah:ayah)'), findsOneWidget);
    expect(find.text('Hadith'), findsOneWidget);

    // The ornate parentheses are bidi-neutral, so in this LTR sheet they took
    // the sheet's direction and rendered mirrored — ﴾…﴿ instead of ﴿…﴾. They
    // are Arabic typography and must be laid out RTL like the reader body,
    // whatever language the chrome happens to be in.
    final verseSample = tester.widget<Directionality>(
      find.ancestor(
        of: find.text('\u{FD3F}\u{2026}\u{FD3E}'),
        matching: find.byType(Directionality),
      ).first,
    );
    expect(verseSample.textDirection, TextDirection.rtl);
  });

  testWidgets('share action shares the chapter title and text', (tester) async {
    final sharePlatform = _FakeSharePlatform();
    SharePlatform.instance = sharePlatform;
    final book = BookProvider()..setBookForTest(_testBook);

    await tester.pumpWidget(_wrap(book, 'ch-01'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.share_rounded));
    await tester.pumpAndSettle();

    expect(sharePlatform.lastParams?.text, 'الباب الأول\n\nنص الباب الأول');
  });
}

class _FakeSharePlatform extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return ShareResult('', ShareResultStatus.success);
  }
}
