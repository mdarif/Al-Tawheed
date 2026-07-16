import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/book/report_mistake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    PackageInfo.setMockInitialValues(
      appName: 'Al-Tawheed',
      packageName: 'com.almarfa.tawheed',
      version: '2.4.0',
      buildNumber: '19',
      buildSignature: '',
    );
  });

  group('buildMistakeReportUri', () {
    test('percent-encodes the body — never + for spaces', () {
      final uri = buildMistakeReportUri(
        email: 'help@example.com',
        subject: 'A subject',
        body: 'two words',
      )!;

      // mailto: bodies are percent-encoded (RFC 6068); a mail client shows a +
      // literally, so `%20` is required and `+` is a bug.
      expect(uri, contains('%20'));
      expect(uri, isNot(contains('+')));
      expect(uri, startsWith('mailto:help@example.com?'));
      expect(Uri.parse(uri).queryParameters['body'], 'two words');
    });

    test('round-trips a body with newlines and Arabic', () {
      final body = 'سطر ۱\nسطر ۲';
      final uri = buildMistakeReportUri(
        email: 'a@b.co',
        subject: 's',
        body: body,
      )!;

      expect(Uri.parse(uri).queryParameters['body'], body);
    });

    test('returns null when there is no usable address', () {
      expect(buildMistakeReportUri(email: '', subject: 's', body: 'b'), isNull);
      expect(
        buildMistakeReportUri(email: 'not-an-email', subject: 's', body: 'b'),
        isNull,
      );
    });
  });

  group('mistakeReportDetails', () {
    test('carries the edition, chapter and version for triage', () {
      final details = mistakeReportDetails(
        seriesId: 'tawheed-ur',
        chapterNumber: 9,
        chapterTitle: 'باب',
        version: '2.4.0 (19)',
      );

      expect(details, contains('tawheed-ur'));
      expect(details, contains('9 — باب'));
      expect(details, contains('2.4.0 (19)'));
    });
  });

  group('mistakeReportPlaintext', () {
    // The clipboard fallback must carry the address, or a report copied on a
    // device with no mail app has nowhere to go.
    test('carries the address and subject inline', () {
      final text = mistakeReportPlaintext(
        email: 'help@example.com',
        subject: 'A subject',
        body: 'the report body',
      );

      expect(text, contains('To: help@example.com'));
      expect(text, contains('Subject: A subject'));
      expect(text, contains('the report body'));
    });
  });

  group('hasBookContact — gates whether the report action is offered', () {
    testWidgets('true when a contact address is configured', (tester) async {
      // AppConfigProvider defaults carry a contact email.
      await tester.pumpWidget(_harness(AppConfigProvider()));
      await tester.pumpAndSettle();

      expect(find.text('HAS'), findsOneWidget);
    });

    testWidgets('false when the address is blank', (tester) async {
      await PreferencesService.instance.saveRemoteJson(
        'app_config',
        jsonEncode({
          'contact': {'email': '', 'subject': 'x'},
        }),
      );
      final config = AppConfigProvider();
      await config.load();

      await tester.pumpWidget(_harness(config));
      await tester.pumpAndSettle();

      // The reader hides the ⋮ "Report a mistake" row in this case.
      expect(find.text('NONE'), findsOneWidget);
    });
  });

  testWidgets('reportBookMistake copies to the clipboard when no mail app opens',
      (tester) async {
    // Stand in for a device with no email account: the launch declines.
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _DecliningLauncher();
    addTearDown(() => UrlLauncherPlatform.instance = original);

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

    await tester.pumpWidget(_harness(AppConfigProvider()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('report'));
    await tester.pumpAndSettle();

    // The report is preserved, address and all, rather than lost to a snackbar.
    expect(copied, isNotNull);
    expect(copied, contains('To: '));
    expect(copied, contains('Edition: tawheed-ur'));
    expect(copied, contains('9 — باب'));
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

/// A url_launcher platform that declines every launch — the mail-app-missing
/// case. Mixing in [MockPlatformInterfaceMixin] bypasses the platform-interface
/// token check so it can be assigned to [UrlLauncherPlatform.instance].
class _DecliningLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => false;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => false;
}

/// Exercises the report helpers the way the reader's ⋮ menu does: a marker that
/// reflects [hasBookContact], and a button that calls [reportBookMistake].
Widget _harness(AppConfigProvider config) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SeriesProvider()),
        ChangeNotifierProvider.value(value: config),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                Text(hasBookContact(context) ? 'HAS' : 'NONE'),
                ElevatedButton(
                  onPressed: () => reportBookMistake(
                    context,
                    chapterNumber: 9,
                    chapterTitle: 'باب',
                  ),
                  child: const Text('report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
