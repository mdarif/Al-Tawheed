import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Test catalog ──────────────────────────────────────────────────────────────

/// Five lectures; lec-001 is the "continue listening" lecture.
/// lec-002, lec-003, lec-004 are the "next 3" batch.
Catalog _testCatalog() {
  const json = '''
{
  "version": 1,
  "book": {
    "id": "book", "title": "Test", "titleArabic": "", "speaker": "S",
    "totalDurationSeconds": 600, "lectureCount": 5,
    "coverImageUrl": "", "language": "Urdu"
  },
  "chapters": [
    {"id": "ch-01", "number": 1, "title": "Chapter 1", "lectureCount": 3},
    {"id": "ch-02", "number": 2, "title": "Chapter 2", "lectureCount": 2}
  ],
  "lectures": [
    {"id": "lec-001", "number": 1, "chapterId": "ch-01", "title": "Part 1",
     "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 2097152},
    {"id": "lec-002", "number": 2, "chapterId": "ch-01", "title": "Part 2",
     "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 2097152},
    {"id": "lec-003", "number": 3, "chapterId": "ch-01", "title": "Part 3",
     "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 2097152},
    {"id": "lec-004", "number": 4, "chapterId": "ch-02", "title": "Part 4",
     "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 2097152},
    {"id": "lec-005", "number": 5, "chapterId": "ch-02", "title": "Part 5",
     "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 2097152}
  ],
  "dailyBenefits": []
}
''';
  return Catalog.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

// ── Widget wrapper ────────────────────────────────────────────────────────────

Widget _wrap({
  required ProgressProvider progress,
  required ConnectivityProvider connectivity,
  required DownloadsProvider downloads,
  bool downloadsFeatureEnabled = true,
}) {
  final catalogProvider = CatalogProvider()..setCatalogForTest(_testCatalog());

  final flags = FeatureFlagsProvider()
    ..setFeaturesJsonForTest({
      'downloads': downloadsFeatureEnabled,
      'continueListening': true,
      'announcements': false,
      'studyMode': false,
    });

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: flags),
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider.value(value: progress),
      ChangeNotifierProvider.value(value: connectivity),
      ChangeNotifierProvider.value(value: downloads),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => SeriesProvider()..load(false)),
      ChangeNotifierProvider(
        create: (ctx) => StudyProgressProvider(
          ctx.read<ProgressProvider>(),
          ctx.read<CatalogProvider>(),
        )..load(),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/player',
            builder: (_, __) => const Scaffold(body: SizedBox()),
          ),
        ],
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressProvider progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    progress = ProgressProvider()..load();
    // Individual tests that need a last-listened lecture call
    // progress.saveProgress('lec-001', 30) themselves.
  });

  // ── Strip is shown ────────────────────────────────────────────────────────

  testWidgets('strip appears when online, flag on, next parts undownloaded',
      (tester) async {
    await progress.saveProgress('lec-001', 30);
    await tester.pumpWidget(_wrap(
      progress: progress,
      connectivity: ConnectivityProvider.testOnline(),
      downloads: DownloadsProvider(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });

  // ── Strip hidden: device offline ──────────────────────────────────────────

  testWidgets('strip is hidden when device is offline', (tester) async {
    await progress.saveProgress('lec-001', 30);
    await tester.pumpWidget(_wrap(
      progress: progress,
      connectivity: ConnectivityProvider.testOffline(),
      downloads: DownloadsProvider(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsNothing);
  });

  // ── Strip hidden: downloads feature flag off ──────────────────────────────

  testWidgets('strip is hidden when downloads feature is disabled', (tester) async {
    await progress.saveProgress('lec-001', 30);
    await tester.pumpWidget(_wrap(
      progress: progress,
      connectivity: ConnectivityProvider.testOnline(),
      downloads: DownloadsProvider(),
      downloadsFeatureEnabled: false,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsNothing);
  });

  // ── Strip hidden: no continue-listening session ───────────────────────────

  testWidgets('strip is hidden when there is no last-listened lecture',
      (tester) async {
    // progress has no saveProgress call → lastLectureId stays null
    await tester.pumpWidget(_wrap(
      progress: progress,
      connectivity: ConnectivityProvider.testOnline(),
      downloads: DownloadsProvider(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsNothing);
  });

  // ── Strip hidden: all next lectures already saved ─────────────────────────

  testWidgets('strip is hidden when the next 3 lectures are all downloaded',
      (tester) async {
    await progress.saveProgress('lec-001', 30);
    final downloads = DownloadsProvider()
      ..seedDownloadedForTest('lec-002')
      ..seedDownloadedForTest('lec-003')
      ..seedDownloadedForTest('lec-004');

    await tester.pumpWidget(_wrap(
      progress: progress,
      connectivity: ConnectivityProvider.testOnline(),
      downloads: downloads,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsNothing);
  });

  // ── Dismiss hides the strip ───────────────────────────────────────────────

  testWidgets('tapping × dismisses the strip for the session', (tester) async {
    await progress.saveProgress('lec-001', 30);
    await tester.pumpWidget(_wrap(
      progress: progress,
      connectivity: ConnectivityProvider.testOnline(),
      downloads: DownloadsProvider(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsNothing);
  });
}
