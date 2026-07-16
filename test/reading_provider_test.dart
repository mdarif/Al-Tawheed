import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('ReadingProvider — bookFontSize', () {
    test('defaults to 20 before any preference is saved', () {
      expect(ReadingProvider().bookFontSize, 20.0);
    });

    test('load() reads the persisted font size', () async {
      await PreferencesService.instance.saveBookFontSize(24.0);

      final p = ReadingProvider()..load();
      expect(p.bookFontSize, 24.0);
    });

    test('setBookFontSize updates the value immediately', () async {
      final p = ReadingProvider()..load();
      await p.setBookFontSize(18.0);
      expect(p.bookFontSize, 18.0);
    });

    test('persisted size is restored by a new provider instance', () async {
      final p1 = ReadingProvider()..load();
      await p1.setBookFontSize(22.0);

      final p2 = ReadingProvider()..load();
      expect(p2.bookFontSize, 22.0);
    });

    test('setBookFontSize is a no-op when the value has not changed', () async {
      final p = ReadingProvider()..load();
      int notifications = 0;
      p.addListener(() => notifications++);

      await p.setBookFontSize(20.0); // same as default
      expect(notifications, 0);
      expect(p.bookFontSize, 20.0);
    });
  });

  // Pinch-to-zoom fires continuously, so it updates live (notify, no disk) and
  // persists once at the end. Without this split a single pinch is dozens of
  // prefs writes.
  group('ReadingProvider — live font size (pinch)', () {
    test('setBookFontSizeLive updates and notifies but does NOT persist',
        () async {
      final p = ReadingProvider()..load();
      int notifications = 0;
      p.addListener(() => notifications++);

      p.setBookFontSizeLive(28.0);

      expect(p.bookFontSize, 28.0);
      expect(notifications, 1);
      // Nothing written yet — a fresh provider still sees the old size.
      expect((ReadingProvider()..load()).bookFontSize, 20.0);
    });

    test('commitBookFontSize persists whatever the live updates left',
        () async {
      final p = ReadingProvider()..load();
      p
        ..setBookFontSizeLive(24.0)
        ..setBookFontSizeLive(30.0); // as if mid-pinch
      await p.commitBookFontSize();

      expect((ReadingProvider()..load()).bookFontSize, 30.0);
    });
  });

  group('ReadingProvider — book scroll offset', () {
    test('defaults to 0 for an unseen chapter', () {
      expect(ReadingProvider().bookScrollOffsetFor('ch-01'), 0.0);
    });

    test('stores and reads back an offset per chapter', () async {
      final p = ReadingProvider()..load();
      await p.setBookScrollOffset('ch-01', 420.0);
      await p.setBookScrollOffset('ch-02', 88.0);

      expect(p.bookScrollOffsetFor('ch-01'), 420.0);
      expect(p.bookScrollOffsetFor('ch-02'), 88.0);
      expect(p.bookScrollOffsetFor('ch-03'), 0.0);
    });

    test('offsets persist across a new provider instance', () async {
      final p1 = ReadingProvider()..load();
      await p1.setBookScrollOffset('ch-01', 256.0);

      final p2 = ReadingProvider()..load();
      expect(p2.bookScrollOffsetFor('ch-01'), 256.0);
    });

    test('does not notify listeners when saving an offset', () async {
      final p = ReadingProvider()..load();
      int notifications = 0;
      p.addListener(() => notifications++);

      await p.setBookScrollOffset('ch-01', 100.0);
      expect(notifications, 0);
    });
  });
}
