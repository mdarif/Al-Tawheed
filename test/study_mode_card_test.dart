import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/home/study_mode_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Catalog _testCatalog() {
  const json = '''
{
  "version": 1,
  "book": {
    "id": "book",
    "title": "Test",
    "titleArabic": "",
    "speaker": "Speaker",
    "totalDurationSeconds": 600,
    "lectureCount": 2,
    "coverImageUrl": "",
    "language": "Urdu"
  },
  "chapters": [
    {"id": "class-01", "number": 1, "title": "Class 01", "lectureCount": 2}
  ],
  "lectures": [
    {"id": "lec-001", "number": 1, "chapterId": "class-01", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-002", "number": 2, "chapterId": "class-01", "title": "P2", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1}
  ],
  "dailyBenefits": []
}
''';
  return Catalog.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  Widget wrap(Widget child) {
    final catalogProvider = CatalogProvider();
    catalogProvider.setCatalogForTest(_testCatalog());
    final progressProvider = ProgressProvider()..load();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalogProvider),
        ChangeNotifierProvider.value(value: progressProvider),
        ChangeNotifierProvider(
          create: (ctx) => StudyProgressProvider(
            ctx.read<ProgressProvider>(),
            ctx.read<CatalogProvider>(),
          )..load(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(body: child),
            ),
            GoRoute(
              path: '/study',
              builder: (_, __) => const Scaffold(
                body: Center(child: Text('Study Hub')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('StudyModeCard shows progress and navigates to study hub',
      (tester) async {
    await tester.pumpWidget(wrap(const StudyModeCard()));
    await tester.pumpAndSettle();

    expect(find.text('Study Mode'), findsOneWidget);
    expect(find.text('0 of 1 classes studied'), findsOneWidget);
    expect(find.text('Start Class 01'), findsOneWidget);

    await tester.tap(find.text('0 of 1 classes studied'));
    await tester.pumpAndSettle();

    expect(find.text('Study Hub'), findsOneWidget);
  });
}
