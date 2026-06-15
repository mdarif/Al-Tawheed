import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/screens/book_reader_screen.dart';
import 'package:myapp/theme/app_theme.dart';

const _testBook = BookContent(
  title: 'كتاب التوحيد',
  author: 'الشيخ محمد بن عبد الوهاب',
  chapters: [
    BookChapter(id: 'intro', number: 0, title: 'مقدمة', text: 'نص المقدمة'),
    BookChapter(
        id: 'ch-01', number: 1, title: 'الباب الأول', text: 'نص الباب الأول'),
    BookChapter(
        id: 'ch-02', number: 2, title: 'الباب الثاني', text: 'نص الباب الثاني'),
  ],
);

Widget _wrap(BookProvider book, String chapterId) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: book),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
