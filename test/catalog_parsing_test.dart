import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';

/// A minimal valid catalog map. Round-tripped through JSON so the nested
/// collections are `List<dynamic>`/`Map<String, dynamic>` exactly like the
/// real `jsonDecode` fetch path — letting tests inject mixed/malformed rows.
Map<String, dynamic> _base() =>
    jsonDecode(jsonEncode(_literal())) as Map<String, dynamic>;

Map<String, dynamic> _literal() => {
      'version': 1,
      'book': {
        'id': 'book-1',
        'title': {'en': 'Test Book'},
        'speaker': {'en': 'Speaker'},
        'totalDurationSeconds': 120,
        'lectureCount': 2,
        'coverImageUrl': 'https://example.com/cover.jpg',
        'language': 'ur',
      },
      'chapters': [
        {'id': 'ch-01', 'number': 1, 'title': {'en': 'One'}, 'lectureCount': 1},
      ],
      'lectures': [
        {
          'id': 'lec-001',
          'number': 1,
          'chapterId': 'ch-01',
          'title': {'en': 'Lecture 1'},
          'audioUrl': 'https://example.com/1.mp3',
          'durationSeconds': 60,
          'fileSizeBytes': 1000,
        },
      ],
      'dailyBenefits': [
        {'id': 'b-1', 'text': {'en': 'Benefit'}, 'source': {'en': 'Src'}},
      ],
    };

void main() {
  group('Catalog.fromJson — happy path', () {
    test('parses a well-formed catalog fully', () {
      final c = Catalog.fromJson(_base());
      expect(c.version, 1);
      expect(c.book.id, 'book-1');
      expect(c.chapters, hasLength(1));
      expect(c.lectures, hasLength(1));
      expect(c.dailyBenefits, hasLength(1));
    });
  });

  group('Catalog.fromJson — resilient list parsing', () {
    test('skips a lecture missing its id but keeps the valid ones', () {
      final json = _base();
      (json['lectures'] as List).add({
        // no 'id'
        'audioUrl': 'https://example.com/bad.mp3',
        'title': {'en': 'Broken'},
      });

      final c = Catalog.fromJson(json);
      expect(c.lectures, hasLength(1));
      expect(c.lectures.single.id, 'lec-001');
    });

    test('keeps a lecture with a missing audioUrl, defaulting it to empty', () {
      // Matches the original contract (empty audioUrl is valid); only a
      // missing id drops a lecture. The player guards against empty sources.
      final json = _base();
      (json['lectures'] as List).add({
        'id': 'lec-002',
        'title': {'en': 'No audio'},
        // no 'audioUrl'
      });

      final c = Catalog.fromJson(json);
      expect(c.lectures.map((l) => l.id), ['lec-001', 'lec-002']);
      expect(c.lectures.last.audioUrl, '');
    });

    test('skips a non-object entry in the lectures list', () {
      final json = _base();
      (json['lectures'] as List).add('not-an-object');

      final c = Catalog.fromJson(json);
      expect(c.lectures, hasLength(1));
    });

    test('skips a chapter missing its id', () {
      final json = _base();
      (json['chapters'] as List).add({'number': 2, 'title': {'en': 'Two'}});

      final c = Catalog.fromJson(json);
      expect(c.chapters.map((ch) => ch.id), ['ch-01']);
    });

    test('skips a daily benefit missing its id', () {
      final json = _base();
      (json['dailyBenefits'] as List).add({'text': {'en': 'no id'}});

      final c = Catalog.fromJson(json);
      expect(c.dailyBenefits.map((b) => b.id), ['b-1']);
    });
  });

  group('Catalog.fromJson — lenient field defaults', () {
    test('a lecture with valid id+audioUrl but missing numbers still loads', () {
      final json = _base();
      (json['lectures'] as List).add({
        'id': 'lec-002',
        'audioUrl': 'https://example.com/2.mp3',
        'title': {'en': 'Sparse'},
        // no number / durationSeconds / fileSizeBytes / chapterId
      });

      final c = Catalog.fromJson(json);
      final sparse = c.lectures.firstWhere((l) => l.id == 'lec-002');
      expect(sparse.number, 0);
      expect(sparse.durationSeconds, 0);
      expect(sparse.fileSizeBytes, 0);
      expect(sparse.chapterId, '');
    });

    test('numeric fields provided as strings are coerced', () {
      final json = _base();
      (json['lectures'] as List).add({
        'id': 'lec-003',
        'audioUrl': 'https://example.com/3.mp3',
        'title': {'en': 'Stringy'},
        'durationSeconds': '90',
        'fileSizeBytes': '2048',
      });

      final c = Catalog.fromJson(json);
      final l = c.lectures.firstWhere((l) => l.id == 'lec-003');
      expect(l.durationSeconds, 90);
      expect(l.fileSizeBytes, 2048);
    });

    test('book parses with missing optional fields (no throw)', () {
      final json = _base();
      json['book'] = {
        'title': {'en': 'Bare'},
        'speaker': {'en': 'X'},
        // no id / coverImageUrl / counts / language
      };

      final c = Catalog.fromJson(json);
      expect(c.book.id, '');
      expect(c.book.coverImageUrl, '');
      expect(c.book.lectureCount, 0);
      expect(c.book.language, 'ur'); // default
    });
  });

  group('Catalog.fromJson — top-level resilience', () {
    test('missing chapters/lectures/dailyBenefits become empty lists', () {
      final json = _base();
      json.remove('chapters');
      json.remove('lectures');
      json.remove('dailyBenefits');

      final c = Catalog.fromJson(json);
      expect(c.chapters, isEmpty);
      expect(c.lectures, isEmpty);
      expect(c.dailyBenefits, isEmpty);
    });

    test('missing version defaults to 1', () {
      final json = _base()..remove('version');
      expect(Catalog.fromJson(json).version, 1);
    });

    test('a missing book throws (catalog is unusable without it)', () {
      final json = _base()..remove('book');
      expect(() => Catalog.fromJson(json), throwsFormatException);
    });
  });
}
