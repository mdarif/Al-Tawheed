import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/announcement_model.dart';

void main() {
  group('Announcement.isActive', () {
    test('is inactive before validFrom', () {
      final ann = Announcement.fromJson({
        'id': 'test',
        'title': 'T',
        'body': 'B',
        'validFrom': '2026-06-01T00:00:00Z',
        'platforms': ['ios'],
      });

      expect(
        ann.isActiveAt(DateTime.utc(2026, 5, 31, 14, 52)),
        isFalse,
      );
    });

    test('is active on and after validFrom', () {
      final ann = Announcement.fromJson({
        'id': 'test',
        'title': 'T',
        'body': 'B',
        'validFrom': '2026-06-01T00:00:00Z',
        'platforms': ['ios'],
      });

      expect(
        ann.isActiveAt(DateTime.utc(2026, 6, 1, 0, 0)),
        isTrue,
      );
    });
  });
}
