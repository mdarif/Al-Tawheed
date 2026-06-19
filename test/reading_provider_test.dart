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
}
