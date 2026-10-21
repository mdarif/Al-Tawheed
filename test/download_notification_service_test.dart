import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/services/download_notification_service.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The download notification is posted from Dart with no BuildContext, so it
/// used to be English-only: `lecture.title.en`, a hard-coded "Download
/// complete" and a hard-coded "Downloads" channel name. These tests pin that
/// every user-visible string follows the chrome locale (and the title follows
/// the same resolution the lecture list uses).
///
/// Like download_cancellation_test.dart this must NOT call
/// `TestWidgetsFlutterBinding.ensureInitialized()` — that stubs `HttpClient`,
/// and the provider tests below drive a real download against a local server.

class _Shown {
  _Shown(this.id, this.title, this.body, this.details);
  final int id;
  final String? title;
  final String? body;
  final AndroidNotificationDetails details;
}

class _FakeAndroidPlugin extends AndroidFlutterLocalNotificationsPlugin {
  final channels = <AndroidNotificationChannel>[];

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async {
    channels.add(notificationChannel);
  }
}

/// Captures what would have been posted instead of calling the platform.
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final android = _FakeAndroidPlugin();
  final shown = <_Shown>[];
  final cancelled = <int>[];

  @override
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    shown.add(_Shown(id, title, body, notificationDetails!.android!));
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelled.add(id);
  }

  /// `resolvePlatformSpecificImplementation<T>` is generic over a type from a
  /// transitive package, so it is answered here rather than overridden.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #resolvePlatformSpecificImplementation) {
      final type = invocation.typeArguments.single;
      return type == AndroidFlutterLocalNotificationsPlugin ? android : null;
    }
    return Future<bool?>.value(true);
  }
}

const _en = Locale('en');
const _ur = Locale('ur');
const _ar = Locale('ar');
const _roman = Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman');

AppLocalizations _l10n(Locale locale) => lookupAppLocalizations(locale);

const _titles = <String, dynamic>{
  'en': 'Class 01 — Part 01',
  'ur': 'درس ۰۱ — حصہ ۰۱',
  'ar': 'الدرس ٠١ — الجزء ٠١',
  'roman': 'Dars 01 — Hissa 01',
};

Lecture _lecture(String audioUrl) => Lecture(
      id: 'lec-1',
      number: 1,
      chapterId: 'ch-01',
      title: _titles,
      audioUrl: audioUrl,
      durationSeconds: 60,
      fileSizeBytes: 2048,
    );

const _urduSeries = SeriesConfig.legacyUrduFallback;

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: false,
  language: 'ar',
  displayName: {'en': 'Arabic'},
  speakerName: {'en': 'Speaker'},
);

Future<HttpServer> _startServer(int bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.add(List<int>.filled(bytes, 1));
    await request.response.close();
  });
  return server;
}

void main() {
  late Directory tempDir;
  late _FakePlugin plugin;
  late DownloadNotificationService original;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dl_notif_l10n_');
    DownloadService.resetForTest(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    plugin = _FakePlugin();
    original = DownloadNotificationService.instance;
    DownloadNotificationService.instance =
        DownloadNotificationService.forTest(plugin);
  });

  tearDown(() async {
    DownloadNotificationService.instance = original;
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('DownloadNotificationService strings', () {
    test('"Download complete" body is the ARB string for each chrome locale',
        () async {
      final service = DownloadNotificationService.forTest(plugin);
      addTearDown(() => service.dismiss('x'));
      final expected = {
        _en: 'Download complete',
        _ur: 'ڈاؤن لوڈ مکمل',
        _ar: 'اكتمل التنزيل',
        _roman: 'Download mukammal',
      };
      for (final entry in expected.entries) {
        await service.showComplete('x', 'T', _l10n(entry.key));
        expect(plugin.shown.last.body, entry.value, reason: '${entry.key}');
      }
    });

    test('the channel is registered with the localized name + description',
        () async {
      final service = DownloadNotificationService.forTest(plugin);
      await service.showProgress('x', 'T', 0.5, _l10n(_ur));

      final ur = _l10n(_ur);
      final channel = plugin.android.channels.last;
      expect(channel.id, 'downloads');
      expect(channel.name, ur.downloadNotificationChannelName);
      expect(channel.description, ur.downloadNotificationChannelDescription);
      expect(channel.name, isNot(_l10n(_en).downloadNotificationChannelName));
      // The per-notification details carry the same name.
      expect(plugin.shown.last.details.channelName, channel.name);
    });

    test(
        'a locale change re-registers the channel (Android renames it in '
        'place); an unchanged locale does not churn it', () async {
      final service = DownloadNotificationService.forTest(plugin);
      await service.init();
      final afterInit = plugin.android.channels.length;

      await service.showProgress('x', 'T', 0.1, _l10n(_en));
      await service.showProgress('x', 'T', 0.2, _l10n(_en));
      expect(
        plugin.android.channels.length,
        afterInit,
        reason: 'English was already registered by init()',
      );

      await service.showProgress('x', 'T', 0.3, _l10n(_ar));
      expect(plugin.android.channels.length, afterInit + 1);
      expect(
        plugin.android.channels.last.name,
        _l10n(_ar).downloadNotificationChannelName,
      );

      await service.showProgress('x', 'T', 0.4, _l10n(_ar));
      expect(plugin.android.channels.length, afterInit + 1);
    });

    test('syncChannel localizes the channel before any download starts',
        () async {
      final service = DownloadNotificationService.forTest(plugin);
      await service.init();
      await service.syncChannel(_l10n(_ur));
      expect(
        plugin.android.channels.last.name,
        _l10n(_ur).downloadNotificationChannelName,
      );
    });
  });

  group('DownloadsProvider posts the notification in the chrome language', () {
    late HttpServer server;
    late LanguageProvider lang;

    setUp(() async {
      server = await _startServer(2048);
      lang = LanguageProvider()..applyLanguageFeatureFlag(true);
    });

    tearDown(() => server.close(force: true));

    Future<({_Shown progress, _Shown complete})> run(
      SeriesConfig series,
    ) async {
      final provider = DownloadsProvider.forSeries(() => series, null, lang);
      final url = 'http://${server.address.host}:${server.port}/a.mp3';
      await provider.download(_lecture(url));
      // showProgress/showComplete are fire-and-forget (unawaited) from the
      // provider; let them reach the fake plugin.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final shown = plugin.shown;
      expect(shown, isNotEmpty);
      final complete = shown.lastWhere((s) => s.details.showProgress != true);
      final progress = shown.firstWhere((s) => s.details.showProgress == true);
      DownloadNotificationService.instance.dismiss('lec-1').ignore();
      return (progress: progress, complete: complete);
    }

    test('Urdu chrome on the Urdu edition: Urdu title and Urdu "complete"',
        () async {
      await lang.setLanguage(AppLanguage.urdu);
      final r = await run(_urduSeries);
      expect(r.progress.title, _titles['ur']);
      expect(r.complete.title, _titles['ur']);
      expect(r.complete.body, 'ڈاؤن لوڈ مکمل');
      expect(
        r.progress.details.channelName,
        _l10n(_ur).downloadNotificationChannelName,
      );
    });

    test('Arabic chrome on the Arabic edition: Arabic title and "complete"',
        () async {
      lang.applySeriesDefault(_arabicSeries);
      expect(lang.language, AppLanguage.arabic);
      final r = await run(_arabicSeries);
      expect(r.progress.title, _titles['ar']);
      expect(r.complete.title, _titles['ar']);
      expect(r.complete.body, 'اكتمل التنزيل');
      expect(
        r.progress.details.channelName,
        _l10n(_ar).downloadNotificationChannelName,
      );
    });

    test('English chrome on the Urdu edition: English everywhere', () async {
      final r = await run(_urduSeries);
      expect(r.progress.title, _titles['en']);
      expect(r.complete.title, _titles['en']);
      expect(r.complete.body, 'Download complete');
      expect(
        r.progress.details.channelName,
        _l10n(_en).downloadNotificationChannelName,
      );
    });

    test('Roman Urdu chrome: Roman Urdu title and "complete"', () async {
      await lang.setLanguage(AppLanguage.romanUrdu);
      final r = await run(_urduSeries);
      expect(r.progress.title, _titles['roman']);
      expect(r.complete.body, 'Download mukammal');
    });

    test(
        'the title resolves exactly as the lecture list does: an explicit '
        'English pick on the Arabic edition keeps the Arabic title but English '
        'chrome strings', () async {
      await lang.setLanguage(AppLanguage.english);
      final r = await run(_arabicSeries);
      expect(r.progress.title, lang.resolveForSeries(_titles, _arabicSeries));
      expect(r.progress.title, _titles['ar']);
      expect(r.complete.body, 'Download complete');
    });

    test('changing the chrome language re-registers the channel', () async {
      final provider =
          DownloadsProvider.forSeries(() => _urduSeries, null, lang);
      addTearDown(provider.dispose);
      await lang.setLanguage(AppLanguage.arabic);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        plugin.android.channels.last.name,
        _l10n(_ar).downloadNotificationChannelName,
      );
    });
  });
}
