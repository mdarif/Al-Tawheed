import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// PreferencesService is the persistence layer every provider reads/writes
// through (progress, bookmarks, downloads, theme, language, ...). These tests
// cover save/load round-trips for each stored key so a broken mapping fails
// here rather than silently surfacing as "my settings don't stick" elsewhere.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesService prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    prefs = PreferencesService.instance;
  });

  group('progress', () {
    test('round-trips per-lecture position and tracks the last played lecture',
        () async {
      expect(prefs.lastLectureId, isNull);
      expect(prefs.lastPositionSeconds, 0);
      expect(prefs.loadAllProgress(), isEmpty);

      await prefs.saveProgress('lec-a', 120);
      await prefs.saveProgress('lec-b', 45);

      expect(prefs.loadAllProgress(), {'lec-a': 120, 'lec-b': 45});
      expect(prefs.lastLectureId, 'lec-b');
      expect(prefs.lastPositionSeconds, 45);
    });
  });

  group('bookmarks', () {
    test('round-trips the bookmark id set', () async {
      expect(prefs.loadBookmarks(), isEmpty);

      await prefs.saveBookmarks({'lec-a', 'lec-c'});

      expect(prefs.loadBookmarks(), {'lec-a', 'lec-c'});
    });
  });

  group('playback speed', () {
    test('defaults to 1.0 and round-trips a saved value', () async {
      expect(prefs.playbackSpeed, 1.0);

      await prefs.savePlaybackSpeed(1.5);

      expect(prefs.playbackSpeed, 1.5);
    });
  });

  group('language', () {
    test('defaults to null and round-trips a saved code', () async {
      expect(prefs.appLanguage, isNull);

      await prefs.saveAppLanguage('ur');

      expect(prefs.appLanguage, 'ur');
    });
  });

  group('theme mode', () {
    test('defaults to dark and round-trips light/system/dark', () async {
      expect(prefs.themeMode, ThemeMode.dark);

      await prefs.saveThemeMode(ThemeMode.light);
      expect(prefs.themeMode, ThemeMode.light);

      await prefs.saveThemeMode(ThemeMode.system);
      expect(prefs.themeMode, ThemeMode.system);

      await prefs.saveThemeMode(ThemeMode.dark);
      expect(prefs.themeMode, ThemeMode.dark);
    });
  });

  group('downloads', () {
    test('round-trips downloaded ids and the wifi-only flag', () async {
      expect(prefs.loadDownloadedIds(), isEmpty);
      expect(prefs.downloadOnWifiOnly, isFalse);

      await prefs.saveDownloadedIds({'lec-a'});
      await prefs.saveDownloadOnWifiOnly(true);

      expect(prefs.loadDownloadedIds(), {'lec-a'});
      expect(prefs.downloadOnWifiOnly, isTrue);
    });
  });

  group('study mode', () {
    test('round-trips studied chapter ids', () async {
      expect(prefs.loadStudiedChapterIds(), isEmpty);

      await prefs.saveStudiedChapterIds({'ch-01', 'ch-02'});

      expect(prefs.loadStudiedChapterIds(), {'ch-01', 'ch-02'});
    });
  });

  group('dismissed announcements', () {
    test('round-trips dismissed announcement ids', () async {
      expect(prefs.loadDismissedAnnouncements(), isEmpty);

      await prefs.saveDismissedAnnouncements({'ann-001'});

      expect(prefs.loadDismissedAnnouncements(), {'ann-001'});
    });
  });

  group('remote JSON cache', () {
    test('round-trips body and reports age once cached', () async {
      expect(prefs.loadRemoteJson('catalog'), isNull);
      expect(prefs.remoteJsonAgeMs('catalog'), isNull);

      await prefs.saveRemoteJson('catalog', '{"lectures": []}');

      expect(prefs.loadRemoteJson('catalog'), '{"lectures": []}');
      expect(prefs.remoteJsonAgeMs('catalog'), isNotNull);
      expect(prefs.remoteJsonAgeMs('catalog')!, greaterThanOrEqualTo(0));
    });

    test('keeps separate caches per key', () async {
      await prefs.saveRemoteJson('catalog', '{"a":1}');
      await prefs.saveRemoteJson('announcements', '{"b":2}');

      expect(prefs.loadRemoteJson('catalog'), '{"a":1}');
      expect(prefs.loadRemoteJson('announcements'), '{"b":2}');
    });
  });
}
