import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/other_apps.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/settings/other_apps_section.dart';

const _quranUrl =
    'https://play.google.com/store/apps/details?id=com.almarfa.alquran';
const _assunnahUrl =
    'https://play.google.com/store/apps/details?id=com.almarfa.assunnah';

const _quranTagline =
    "A beautiful offline Qur'an reader — Uthmani & IndoPak, Urdu, Hindi & English.";
const _assunnahTagline =
    'Hadith in Urdu, Arabic and English, with scholars’ rulings. Works offline.';

Widget _harness({Locale? locale, double textScale = 1}) => MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: textScale == 1
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child!,
              ),
      home: const Scaffold(
        body: SingleChildScrollView(child: OtherAppsSection()),
      ),
    );

/// A url_launcher platform that records launches and either accepts or
/// declines them. [MockPlatformInterfaceMixin] bypasses the token check so it
/// can be assigned to [UrlLauncherPlatform.instance].
class _FakeLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _FakeLauncher({required this.accept});
  final bool accept;
  final launched = <String>[];
  final modes = <PreferredLaunchMode>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => accept;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    return accept;
  }
}

_FakeLauncher _installLauncher(WidgetTester tester, {required bool accept}) {
  final original = UrlLauncherPlatform.instance;
  final fake = _FakeLauncher(accept: accept);
  UrlLauncherPlatform.instance = fake;
  addTearDown(() => UrlLauncherPlatform.instance = original);
  return fake;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kOtherApps (data)', () {
    test('lists exactly Al Quran Reader and As-Sunnah Search', () {
      expect(
        kOtherApps.map((a) => (a.name, a.packageId)).toList(),
        [
          ('Al Quran Reader', 'com.almarfa.alquran'),
          ('As-Sunnah Search', 'com.almarfa.assunnah'),
        ],
      );
    });

    test('builds the exact https Google Play listing URL', () {
      expect(
        kOtherApps.map((a) => a.listingUrl).toList(),
        [_quranUrl, _assunnahUrl],
      );
      for (final app in kOtherApps) {
        expect(Uri.parse(app.listingUrl).scheme, 'https');
      }
    });

    test("never lists this app's own package or the unrelated .ask app", () {
      final ids = kOtherApps.map((a) => a.packageId);
      expect(ids, isNot(contains(kOwnPackageId)));
      expect(kOwnPackageId, 'com.almarfa.tawheed');
      expect(ids, isNot(contains('com.almarfa.assunnah.ask')));
    });

    test('otherAppsExcluding drops whichever package is passed (own app)', () {
      expect(
        otherAppsExcluding('com.almarfa.assunnah').map((a) => a.packageId),
        ['com.almarfa.alquran'],
      );
      expect(
        otherAppsExcluding(kOwnPackageId).map((a) => a.packageId),
        ['com.almarfa.alquran', 'com.almarfa.assunnah'],
      );
    });
  });

  group('OtherAppsSection — Android', () {
    testWidgets(
      'shows the header, both apps with taglines, and the footer',
      (tester) async {
        await tester.pumpWidget(_harness());
        await tester.pumpAndSettle();

        expect(find.text('Our other apps'), findsOneWidget);
        expect(find.text('Al Quran Reader'), findsOneWidget);
        expect(find.text('As-Sunnah Search'), findsOneWidget);
        expect(find.text(_quranTagline), findsOneWidget);
        expect(find.text(_assunnahTagline), findsOneWidget);
        expect(find.text('Opens in Google Play.'), findsOneWidget);
        expect(
          find.byKey(WidgetKeys.settingsOtherApp('com.almarfa.alquran')),
          findsOneWidget,
        );
        expect(
          find.byKey(WidgetKeys.settingsOtherApp('com.almarfa.assunnah')),
          findsOneWidget,
        );
        expect(find.text('Sharah Kitab at-Tawheed'), findsNothing);
        expect(find.byIcon(Icons.open_in_new_rounded), findsNWidgets(2));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'each row has a 44dp app icon that loads from the bundle',
      (tester) async {
        await tester.pumpWidget(_harness());
        // Asset bytes arrive on the real event loop, not the fake-async one.
        await tester.runAsync(() async {
          for (final app in kOtherApps) {
            await rootBundle.load(app.iconAsset);
          }
        });
        await tester.pumpAndSettle();

        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(images, hasLength(2));
        for (final image in images) {
          expect(image.width, 44);
          expect(image.height, 44);
        }
        // No fallback glyph means the PNG decoded.
        expect(find.byIcon(Icons.apps_rounded), findsNothing);
        expect(
          kOtherApps.map((a) => a.iconAsset),
          everyElement(startsWith('assets/brand/other_apps/')),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'tapping a row opens its exact Play URL externally',
      (tester) async {
        final launcher = _installLauncher(tester, accept: true);
        await tester.pumpWidget(_harness());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(WidgetKeys.settingsOtherApp('com.almarfa.alquran')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(WidgetKeys.settingsOtherApp('com.almarfa.assunnah')),
        );
        await tester.pumpAndSettle();

        expect(launcher.launched, [_quranUrl, _assunnahUrl]);
        expect(
          launcher.modes,
          everyElement(PreferredLaunchMode.externalApplication),
        );
        expect(find.byType(SnackBar), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'a failed launch shows a snackbar whose Copy link copies the URL',
      (tester) async {
        final launcher = _installLauncher(tester, accept: false);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await tester.pumpWidget(_harness());
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(WidgetKeys.settingsOtherApp('com.almarfa.assunnah')),
        );
        await tester.pumpAndSettle();

        expect(launcher.launched, [_assunnahUrl]);
        expect(find.text('Couldn’t open Google Play'), findsOneWidget);
        expect(find.text('Copy link'), findsOneWidget);
        expect(copied, isNull); // nothing copied until the user asks

        await tester.tap(find.text('Copy link'));
        await tester.pumpAndSettle();

        expect(copied, _assunnahUrl);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'rows announce "<name>, opens in Google Play" and are ≥48dp',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness());
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel('Al Quran Reader, opens in Google Play'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('As-Sunnah Search, opens in Google Play'),
          findsOneWidget,
        );
        for (final id in ['com.almarfa.alquran', 'com.almarfa.assunnah']) {
          final size =
              tester.getSize(find.byKey(WidgetKeys.settingsOtherApp(id)));
          expect(size.height, greaterThanOrEqualTo(48), reason: id);
          expect(size.width, greaterThanOrEqualTo(48), reason: id);
        }
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'taglines and chrome are translated; app names are not',
      (tester) async {
        await tester.pumpWidget(_harness(locale: const Locale('ar')));
        await tester.pumpAndSettle();

        expect(find.text('تطبيقاتنا الأخرى'), findsOneWidget);
        expect(find.text('Al Quran Reader'), findsOneWidget);
        expect(find.text('As-Sunnah Search'), findsOneWidget);
        expect(find.text(_quranTagline), findsNothing);
        expect(find.text(_assunnahTagline), findsNothing);
        expect(find.text('يُفتح في Google Play.'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    for (final locale in [
      const Locale('ar'),
      const Locale('ur'),
      const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
    ]) {
      testWidgets(
        'lays out in $locale at 2.0 text scale without overflow',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(_harness(locale: locale, textScale: 2));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          for (final id in ['com.almarfa.alquran', 'com.almarfa.assunnah']) {
            final rect =
                tester.getRect(find.byKey(WidgetKeys.settingsOtherApp(id)));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.right, lessThanOrEqualTo(360));
            expect(rect.left, greaterThanOrEqualTo(0));
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }

    testWidgets(
      'Urdu (Nastaliq) taglines get 1.8–2.1 line height',
      (tester) async {
        await tester.pumpWidget(_harness(locale: const Locale('ur')));
        await tester.pumpAndSettle();

        final tagline = tester.widget<Text>(
          find.descendant(
            of: find.byKey(WidgetKeys.settingsOtherApp('com.almarfa.alquran')),
            matching: find.textContaining('قرآن'),
          ),
        );
        expect(tagline.style?.height, inInclusiveRange(1.8, 2.1));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('OtherAppsSection — not Android', () {
    testWidgets(
      'is hidden entirely on iOS (no App Store IDs yet)',
      (tester) async {
        await tester.pumpWidget(_harness());
        await tester.pumpAndSettle();

        expect(find.text('Our other apps'), findsNothing);
        expect(find.text('Al Quran Reader'), findsNothing);
        expect(find.text('Opens in Google Play.'), findsNothing);
        expect(find.byType(Image), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });
}
