// Golden / screenshot regression tests.
//
// These tests capture pixel-level snapshots of key custom widgets and fail if
// the rendered output changes unexpectedly. They guard against accidental
// colour, spacing, or icon regressions across theme variants.
//
// TAG: golden
// These tests are tagged 'golden' and excluded from the fast ubuntu CI gate
// (flutter-ci.yml). They run in the macos regression workflow (flutter-
// regression.yml) where the renderer matches the machine that generated them.
//
// GENERATING / UPDATING GOLDENS
//   flutter test test/golden_test.dart --update-goldens
//
// Run that command after any intentional visual change, then commit the
// updated PNG files in test/goldens/.

@Tags(['golden'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/offline_status_banner.dart';
import 'package:myapp/widgets/settings/about_card.dart';
import 'package:myapp/widgets/settings/theme_mode_switch.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Tolerance comparator ──────────────────────────────────────────────────────
// Allows up to 1 % of pixels to differ — absorbs sub-pixel antialiasing
// differences between macOS (local) and ubuntu (CI) without hiding real
// visual regressions.

class _ToleranceComparator extends LocalFileComparator {
  _ToleranceComparator(super.testFile);

  static const double _maxDiffFraction = 0.01; // 1 %

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if ((result.diffPercent / 100) <= _maxDiffFraction) return true;
    fail(
      'Golden mismatch for $golden: ${result.diffPercent.toStringAsFixed(2)} % '
      'pixels differ (tolerance $_maxDiffFraction %).\n'
      'To regenerate: flutter test test/golden_test.dart --update-goldens',
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _themeSwitchWrap({required ThemeMode themeMode}) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider()..load(),
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ThemeModeSwitch()),
    ),
  );
}

Widget _bannerWrap({required ThemeMode themeMode}) {
  final flags = FeatureFlagsProvider()
    ..setFeaturesJsonForTest({'downloads': true});

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConnectivityProvider>(
        create: (_) => ConnectivityProvider.testOffline(),
      ),
      ChangeNotifierProvider<FeatureFlagsProvider>.value(value: flags),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Column(children: [OfflineStatusBanner()])),
    ),
  );
}

Widget _aboutCardWrap({required ThemeMode themeMode}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AboutCard(about: AppConfigModel.defaults.about),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Replace the default comparator with a tolerance-aware one.
    goldenFileComparator = _ToleranceComparator(
      (goldenFileComparator as LocalFileComparator).basedir.resolve(
        'golden_test.dart',
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
  });

  // ── ThemeModeSwitch ──────────────────────────────────────────────────────

  testWidgets('ThemeModeSwitch — light theme', (tester) async {
    await tester.pumpWidget(
      _themeSwitchWrap(themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ThemeModeSwitch),
      matchesGoldenFile('goldens/theme_switch__light.png'),
    );
  });

  testWidgets('ThemeModeSwitch — dark theme', (tester) async {
    await tester.pumpWidget(
      _themeSwitchWrap(themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ThemeModeSwitch),
      matchesGoldenFile('goldens/theme_switch__dark.png'),
    );
  });

  // ── OfflineStatusBanner ──────────────────────────────────────────────────

  testWidgets('OfflineStatusBanner — offline, light theme', (tester) async {
    await tester.pumpWidget(
      _bannerWrap(themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(OfflineStatusBanner),
      matchesGoldenFile('goldens/offline_banner__light.png'),
    );
  });

  testWidgets('OfflineStatusBanner — offline, dark theme', (tester) async {
    await tester.pumpWidget(
      _bannerWrap(themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(OfflineStatusBanner),
      matchesGoldenFile('goldens/offline_banner__dark.png'),
    );
  });

  // ── AboutCard ────────────────────────────────────────────────────────────
  // Captures the two-zone layout: identity zone (book cover, title, lecturer)
  // and gold-tinted stats strip. The book cover image renders as a grey
  // placeholder in tests — that's expected and consistent.

  testWidgets('AboutCard — light theme', (tester) async {
    await tester.pumpWidget(
      _aboutCardWrap(themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AboutCard),
      matchesGoldenFile('goldens/about_card__light.png'),
    );
  });

  testWidgets('AboutCard — dark theme', (tester) async {
    await tester.pumpWidget(
      _aboutCardWrap(themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AboutCard),
      matchesGoldenFile('goldens/about_card__dark.png'),
    );
  });
}
