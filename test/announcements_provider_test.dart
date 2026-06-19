import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/models/announcement_model.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/services/preferences_service.dart';

Announcement _ann({String id = 'ann-1', String title = 'Test'}) =>
    Announcement.fromJson({
      'id': id,
      'title': {'en': title},
      'body': {'en': 'Body text'},
      'platforms': ['android', 'ios'],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('AnnouncementsProvider — visible', () {
    test('starts empty before any data is loaded', () {
      expect(AnnouncementsProvider().visible, isEmpty);
    });

    test('returns all active injected announcements', () {
      final p = AnnouncementsProvider()
        ..setAnnouncementsForTest([_ann(id: 'a1'), _ann(id: 'a2')]);
      expect(p.visible, hasLength(2));
    });

    test('hides the dismissed announcement immediately', () async {
      final p = AnnouncementsProvider()
        ..setAnnouncementsForTest([_ann(id: 'a1'), _ann(id: 'a2')]);
      await p.dismiss('a1');
      expect(p.visible.map((a) => a.id), ['a2']);
    });

    test('allows dismissing all announcements', () async {
      final p = AnnouncementsProvider()
        ..setAnnouncementsForTest([_ann(id: 'a1'), _ann(id: 'a2')]);
      await p.dismiss('a1');
      await p.dismiss('a2');
      expect(p.visible, isEmpty);
    });
  });

  group('AnnouncementsProvider — dismiss persistence', () {
    test('dismissed id is not visible after a fresh load', () async {
      final body = jsonEncode({
        'version': 1,
        'announcements': [
          {
            'id': 'a1',
            'title': {'en': 'One'},
            'body': {'en': 'B'},
            'platforms': ['android', 'ios'],
          },
          {
            'id': 'a2',
            'title': {'en': 'Two'},
            'body': {'en': 'B'},
            'platforms': ['android', 'ios'],
          },
        ],
      });
      await PreferencesService.instance.saveRemoteJson('announcements', body);

      final p1 = AnnouncementsProvider();
      await p1.load();
      expect(p1.visible, hasLength(2));

      await p1.dismiss('a1');

      // New provider instance re-reads dismissed ids from prefs on load.
      final p2 = AnnouncementsProvider();
      await p2.load();
      expect(p2.visible, hasLength(1));
      expect(p2.visible.single.id, 'a2');
    });
  });

  group('AnnouncementsProvider — load()', () {
    test('applies announcements from the seeded cache', () async {
      await PreferencesService.instance.saveRemoteJson(
        'announcements',
        jsonEncode({
          'version': 1,
          'announcements': [
            {
              'id': 'a1',
              'title': {'en': 'Update available'},
              'body': {'en': 'Please update the app.'},
              'platforms': ['android', 'ios'],
            },
          ],
        }),
      );

      final p = AnnouncementsProvider();
      await p.load();

      expect(p.visible, hasLength(1));
      expect(p.visible.single.id, 'a1');
    });

    test('silently ignores a payload whose version exceeds the supported maximum',
        () async {
      // AppConfig.maxSupportedAnnouncementsVersion == 1; version 2 must be dropped.
      await PreferencesService.instance.saveRemoteJson(
        'announcements',
        jsonEncode({
          'version': 2,
          'announcements': [
            {
              'id': 'a1',
              'title': {'en': 'Future format'},
              'body': {'en': 'B'},
              'platforms': ['android', 'ios'],
            },
          ],
        }),
      );

      final p = AnnouncementsProvider();
      await p.load();

      expect(p.visible, isEmpty);
    });

    test('stays empty and does not throw when the fetch fails', () async {
      // No cache seeded — RemoteContentService throws NoCachedContentException,
      // which load() catches silently.
      final p = AnnouncementsProvider();
      await p.load();
      expect(p.visible, isEmpty);
    });
  });
}
