import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/theme/app_semantic_colors.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/section_tab_header.dart';

const _bookmarksKey = ValueKey<String>('test.tab.bookmarks');
const _downloadsKey = ValueKey<String>('test.tab.downloads');

const _twoTabs = [
  SectionTab(label: 'Bookmarks', count: 3, tabKey: _bookmarksKey),
  SectionTab(label: 'Downloads', count: 5, tabKey: _downloadsKey),
];

Widget _host({
  List<SectionTab> tabs = _twoTabs,
  String title = 'Library',
  String? subtitle,
  bool showBack = false,
  Locale? locale,
  double textScale = 1.0,
  ThemeData? theme,
  TabController? controller,
}) {
  Widget header(BuildContext context) => SectionTabHeader(
        title: title,
        subtitle: subtitle,
        tabs: tabs,
        showBack: showBack,
        controller: controller,
      );

  Widget body = Scaffold(
    body: Column(
      children: [
        Builder(builder: header),
        const Expanded(child: Center(child: Text('body'))),
      ],
    ),
  );
  if (tabs.isNotEmpty && controller == null) {
    body = DefaultTabController(length: tabs.length, child: body);
  }

  return MaterialApp(
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
    home: body,
  );
}

void main() {
  testWidgets('renders only a plain title when there are no tabs',
      (tester) async {
    await tester.pumpWidget(_host(tabs: const []));

    expect(find.text('Library'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('renders an underline TabBar with a count after each label',
      (tester) async {
    await tester.pumpWidget(_host());

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('a tab without a count shows only its label', (tester) async {
    await tester.pumpWidget(
      _host(
        tabs: const [
          SectionTab(label: 'Book'),
          SectionTab(label: 'Study'),
        ],
        title: 'Read',
      ),
    );

    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('count uses the secondary text colour, not the label colour',
      (tester) async {
    await tester.pumpWidget(_host());

    final secondary =
        AppTheme.light.extension<AppSemanticColors>()!.secondaryText;
    expect(tester.widget<Text>(find.text('3')).style?.color, secondary);
  });

  testWidgets('selected tab is underlined with the brand colour',
      (tester) async {
    await tester.pumpWidget(_host());

    final brand = AppTheme.light.extension<AppSemanticColors>()!.brand;
    final indicator = tester.widget<TabBar>(find.byType(TabBar)).indicator;
    expect(indicator, isA<UnderlineTabIndicator>());
    expect((indicator! as UnderlineTabIndicator).borderSide.color, brand);
  });

  testWidgets('shows the subtitle beside the title', (tester) async {
    await tester.pumpWidget(_host(title: 'Read', subtitle: 'Kitab at-Tawheed'));

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Kitab at-Tawheed'), findsOneWidget);
  });

  testWidgets('tapping a tab moves the shared controller', (tester) async {
    await tester.pumpWidget(_host());
    final controller =
        DefaultTabController.of(tester.element(find.byType(TabBar)));
    expect(controller.index, 0);

    await tester.tap(find.byKey(_downloadsKey));
    await tester.pumpAndSettle();

    expect(controller.index, 1);
  });

  testWidgets('every tab is at least 48dp tall and wide', (tester) async {
    await tester.pumpWidget(_host());

    for (final key in [_bookmarksKey, _downloadsKey]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('back button pops the route and is 48dp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: SectionTabHeader(title: 'Library', showBack: true),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    final size = tester.getSize(find.byType(BackButton));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(SectionTabHeader), findsNothing);
  });

  testWidgets('count follows the chrome locale digits (Arabic)',
      (tester) async {
    await tester.pumpWidget(
      _host(
        locale: const Locale('ar'),
        title: 'المكتبة',
        tabs: const [
          SectionTab(label: 'الإشارات المرجعية', count: 3),
          SectionTab(label: 'التنزيلات', count: 5),
        ],
      ),
    );

    expect(find.text('٣'), findsOneWidget);
    expect(find.text('٥'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  for (final (name, locale, title, labels) in [
    (
      'Arabic',
      const Locale('ar'),
      'المكتبة',
      ['الإشارات المرجعية', 'التنزيلات'],
    ),
    (
      'Urdu',
      const Locale('ur'),
      'لائبریری',
      ['بک مارکس', 'ڈاؤن لوڈز'],
    ),
  ]) {
    testWidgets('$name RTL at 2.0 text scale lays out without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          locale: locale,
          title: title,
          subtitle: 'كتاب التوحيد',
          textScale: 2.0,
          tabs: [
            SectionTab(label: labels[0], count: 12, tabKey: _bookmarksKey),
            SectionTab(label: labels[1], count: 34, tabKey: _downloadsKey),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // RTL: the first tab sits on the right-hand side.
      expect(
        tester.getCenter(find.byKey(_bookmarksKey)).dx,
        greaterThan(tester.getCenter(find.byKey(_downloadsKey)).dx),
      );
      for (final key in [_bookmarksKey, _downloadsKey]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
    });
  }

  testWidgets('English LTR at 2.0 text scale lays out without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        textScale: 2.0,
        subtitle: 'Kitab at-Tawheed — Shaikh Abdullah Nasir Rahmani',
        theme: AppTheme.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(find.byKey(_bookmarksKey)).dx,
      lessThan(tester.getCenter(find.byKey(_downloadsKey)).dx),
    );
  });
}
