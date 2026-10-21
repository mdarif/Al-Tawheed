import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_semantic_colors.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/widgets/class_grid.dart';

import 'support/fake_audio_playback.dart';

String _p2(int n) => n.toString().padLeft(2, '0');

const _counts = [2, 3, 3, 3, 4, 4, 2, 4, 2, 4, 4, 5, 3, 5, 2];

Catalog _catalog({int classes = 15}) {
  final chapters = <Chapter>[];
  final lectures = <Lecture>[];
  var n = 0;
  for (var c = 1; c <= classes; c++) {
    final id = 'class-${_p2(c)}';
    chapters.add(
      Chapter(
        id: id,
        number: c,
        title: {'en': 'Class ${_p2(c)}'},
        lectureCount: _counts[c - 1],
      ),
    );
    for (var p = 1; p <= _counts[c - 1]; p++) {
      n++;
      lectures.add(
        Lecture(
          id: 'lec-${n.toString().padLeft(3, '0')}',
          number: n,
          chapterId: id,
          title: {'en': 'Class $c - Part $p'},
          audioUrl: 'https://example.com/$n.mp3',
          durationSeconds: 600,
          fileSizeBytes: 1,
        ),
      );
    }
  }
  return Catalog(
    version: 1,
    book: Book(
      id: 'b',
      title: const {'en': 'B'},
      speaker: const {'en': 'S'},
      totalDurationSeconds: n * 600,
      lectureCount: n,
      coverImageUrl: '',
      language: 'Urdu',
    ),
    chapters: chapters,
    lectures: lectures,
    dailyBenefits: const [],
  );
}

Future<PlayerNotifier> _pump(
  WidgetTester tester, {
  required Catalog catalog,
  ProgressProvider? progress,
  PlayerNotifier? player,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  ValueChanged<Chapter>? onSelect,
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final prog = progress ?? (ProgressProvider()..load());
  final downloads = DownloadsProvider();
  final conn = ConnectivityProvider.testOnline();
  final p =
      player ?? PlayerNotifier(FakeAudioPlayback(), prog, downloads, conn);
  if (player == null) addTearDown(p.dispose);
  final rtl = locale.languageCode == 'ar' || locale.languageCode == 'ur';

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: prog),
        ChangeNotifierProvider.value(value: p),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ClassGrid(catalog: catalog, onSelect: onSelect ?? (_) {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return p;
}

Finder _cell(String id) => find.byKey(WidgetKeys.searchClassCell(id));

Material _material(WidgetTester tester, String id) => tester.widget<Material>(
      find.descendant(of: _cell(id), matching: find.byType(Material)).first,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets('one cell per class, numbered, with its part count',
      (tester) async {
    await _pump(tester, catalog: _catalog());

    expect(find.byKey(WidgetKeys.searchClassGrid), findsOneWidget);
    for (var c = 1; c <= 15; c++) {
      expect(_cell('class-${_p2(c)}'), findsOneWidget);
    }
    expect(
      find.descendant(of: _cell('class-01'), matching: find.text('01')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _cell('class-01'), matching: find.text('2 parts')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _cell('class-12'), matching: find.text('5 parts')),
      findsOneWidget,
    );
  });

  testWidgets('five columns: rows of five, wrapping to a fourth row',
      (tester) async {
    await _pump(tester, catalog: _catalog());

    double top(int c) => tester.getTopLeft(_cell('class-${_p2(c)}')).dy;
    double left(int c) => tester.getTopLeft(_cell('class-${_p2(c)}')).dx;
    expect({for (var c = 1; c <= 5; c++) top(c)}, hasLength(1));
    expect({for (var c = 6; c <= 10; c++) top(c)}, hasLength(1));
    expect(top(6), greaterThan(top(1)));
    expect(top(11), greaterThan(top(6)));
    expect(left(6), left(1));
    for (var c = 1; c < 5; c++) {
      expect(left(c + 1), greaterThan(left(c)));
    }
  });

  testWidgets('cells are at least 48dp, also at 2x text', (tester) async {
    for (final scale in [1.0, 2.0]) {
      await _pump(
        tester,
        catalog: _catalog(),
        textScaler: TextScaler.linear(scale),
      );
      for (var c = 1; c <= 15; c++) {
        final size = tester.getSize(_cell('class-${_p2(c)}'));
        expect(size.height, greaterThanOrEqualTo(48), reason: 'c$c @$scale');
        expect(size.width, greaterThanOrEqualTo(48), reason: 'c$c @$scale');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('tapping a cell reports its chapter', (tester) async {
    Chapter? picked;
    await _pump(tester, catalog: _catalog(), onSelect: (c) => picked = c);

    await tester.tap(_cell('class-09'));
    await tester.pump();

    expect(picked?.id, 'class-09');
    expect(picked?.number, 9);
  });

  testWidgets('finished = every part complete; continue-here = last played',
      (tester) async {
    final handle = tester.ensureSemantics();
    final progress = ProgressProvider()..load();
    // Class 01 (lectures 1-2) fully listened; Class 02 only half-way.
    await progress.saveProgress('lec-001', 600);
    await progress.saveProgress('lec-002', 600);
    await progress.saveProgress('lec-003', 600);
    await progress.saveProgress('lec-004', 600);
    await progress.saveProgress('lec-005', 100);
    await _pump(tester, catalog: _catalog(), progress: progress);

    final semantic = Theme.of(tester.element(_cell('class-01')))
        .extension<AppSemanticColors>()!;

    // Finished: brand-subtle fill and a check.
    expect(_material(tester, 'class-01').color, semantic.brandSubtle);
    expect(
      find.descendant(
        of: _cell('class-01'),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(_cell('class-01')).label,
      'Class 01, 2 parts, finished',
    );

    // Class 02 has parts 3, 4 done and 5 started? lectures 3-5 are Class 02:
    // 5 is only 100/600 listened, so not finished — but it IS the last played.
    expect(_material(tester, 'class-02').color, isNot(semantic.brandSubtle));
    expect(
      find.descendant(
        of: _cell('class-02'),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
    final current =
        _material(tester, 'class-02').shape as RoundedRectangleBorder;
    expect(current.side.width, 2);
    expect(current.side.color, semantic.brand);
    expect(
      tester.getSemantics(_cell('class-02')).label,
      'Class 02, 3 parts, in progress',
    );

    // Everything else is plain.
    final plain = _material(tester, 'class-03').shape as RoundedRectangleBorder;
    expect(plain.side.width, 1);
    expect(
      tester.getSemantics(_cell('class-03')).label,
      'Class 03, 3 parts',
    );
    handle.dispose();
  });

  testWidgets('a finished class can also be the continue-here class',
      (tester) async {
    final progress = ProgressProvider()..load();
    await progress.saveProgress('lec-001', 600);
    await progress.saveProgress('lec-002', 600); // last played, class done
    await _pump(tester, catalog: _catalog(), progress: progress);

    final semantic = Theme.of(tester.element(_cell('class-01')))
        .extension<AppSemanticColors>()!;
    expect(_material(tester, 'class-01').color, semantic.brandSubtle);
    final shape = _material(tester, 'class-01').shape as RoundedRectangleBorder;
    expect(shape.side.width, 2);
  });

  testWidgets('the lecture loaded in the player counts as continue-here',
      (tester) async {
    final progress = ProgressProvider()..load();
    final downloads = DownloadsProvider();
    final player = PlayerNotifier(
      FakeAudioPlayback(),
      progress,
      downloads,
      ConnectivityProvider.testOnline(),
    );
    addTearDown(player.dispose);
    final catalog = _catalog();
    player.setPlaybackStateForTest(catalog.lectureById('lec-045')!);
    await _pump(
      tester,
      catalog: catalog,
      progress: progress,
      player: player,
    );

    final shape = _material(tester, 'class-14').shape as RoundedRectangleBorder;
    expect(shape.side.width, 2);
    final other = _material(tester, 'class-13').shape as RoundedRectangleBorder;
    expect(other.side.width, 1);
  });

  testWidgets('a fresh install marks nothing', (tester) async {
    await _pump(tester, catalog: _catalog());

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    for (var c = 1; c <= 15; c++) {
      final shape =
          _material(tester, 'class-${_p2(c)}').shape as RoundedRectangleBorder;
      expect(shape.side.width, 1, reason: 'class $c');
    }
  });

  for (final loc in [
    const Locale('ar'),
    const Locale('ur'),
    const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
  ]) {
    testWidgets('localised digits, label and no overflow at 2x ($loc)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final progress = ProgressProvider()..load();
      await progress.saveProgress('lec-001', 600);
      await progress.saveProgress('lec-002', 600);
      await _pump(
        tester,
        catalog: _catalog(),
        progress: progress,
        locale: loc,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      final l10n = lookupAppLocalizations(loc);
      final script = loc.scriptCode == 'roman' ? 'en' : loc.languageCode;
      String d(String text) => localizedDigitsInString(text, script);
      expect(
        tester.getSemantics(_cell('class-01')).label,
        l10n.searchClassCell('finished', d('01'), d(l10n.partsCount(2))),
      );
      expect(
        find.descendant(of: _cell('class-12'), matching: find.text(d('12'))),
        findsOneWidget,
      );
      handle.dispose();
    });
  }

  testWidgets('RTL puts class 01 at the right edge', (tester) async {
    await _pump(tester, catalog: _catalog(), locale: const Locale('ur'));

    expect(
      tester.getCenter(_cell('class-01')).dx,
      greaterThan(tester.getCenter(_cell('class-02')).dx),
    );
  });

  testWidgets('dark theme renders without error', (tester) async {
    final progress = ProgressProvider()..load();
    await progress.saveProgress('lec-001', 600);
    await progress.saveProgress('lec-002', 600);
    await _pump(tester, catalog: _catalog(), progress: progress, dark: true);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('renders nothing for a catalogue with no chapters',
      (tester) async {
    await _pump(
      tester,
      catalog: Catalog(
        version: 1,
        book: _catalog().book,
        chapters: const [],
        lectures: _catalog().lectures,
        dailyBenefits: const [],
      ),
    );

    expect(find.byKey(WidgetKeys.searchClassGrid), findsNothing);
  });
}
