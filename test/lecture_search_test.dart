import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/utils/lecture_search.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

Chapter _chapter(int number, Map<String, dynamic> title) => Chapter(
      id: 'class-${number.toString().padLeft(2, '0')}',
      number: number,
      title: title,
      lectureCount: 0,
    );

Lecture _lecture(
  int number,
  Map<String, dynamic> title, {
  String chapterId = '',
}) =>
    Lecture(
      id: 'lec-${number.toString().padLeft(3, '0')}',
      number: number,
      chapterId: chapterId,
      title: title,
      audioUrl: 'https://example.com/$number.mp3',
      durationSeconds: 60,
      fileSizeBytes: 1,
    );

String _p2(int n) => n.toString().padLeft(2, '0');

/// ASCII digits -> Extended Arabic-Indic (۰-۹), as the Urdu catalogue writes.
String _urduDigits(String s) => s.replaceAllMapped(
      RegExp(r'\d'),
      (m) => String.fromCharCode(0x06F0 + int.parse(m[0]!)),
    );

/// The real Urdu edition's shape: 15 classes, lectureCounts below, lecture
/// numbers global 1..50 (Class 12 parts = lectures 36-40; lecture 12 =
/// Class 05 - Part 01).
const _urduCounts = [2, 3, 3, 3, 4, 4, 2, 4, 2, 4, 4, 5, 3, 5, 2];

List<Chapter> _urduChapters() => [
      for (var i = 1; i <= _urduCounts.length; i++)
        _chapter(i, {
          'en': 'Class ${_p2(i)}',
          'ur': 'درس ${_urduDigits(_p2(i))}',
          'roman': 'Dars ${_p2(i)}',
        }),
    ];

List<Lecture> _urduLectures() {
  final out = <Lecture>[];
  var n = 0;
  for (var c = 1; c <= _urduCounts.length; c++) {
    for (var p = 1; p <= _urduCounts[c - 1]; p++) {
      n++;
      out.add(
        _lecture(
          n,
          {
            'en': 'Class ${_p2(c)} — Part ${_p2(p)}',
            'ur': 'درس ${_urduDigits(_p2(c))} — حصہ ${_urduDigits(_p2(p))}',
            'roman': 'Dars ${_p2(c)} — Hissa ${_p2(p)}',
          },
          chapterId: 'class-${_p2(c)}',
        ),
      );
    }
  }
  return out;
}

/// Arabic edition: no chapters, `chapterId` empty, titles {ar, en}. A
/// representative subset of the 91 real lectures (every "third" ordinal,
/// plus decoys).
List<Lecture> _arabicLectures() {
  const rows = <int, String>{
    1: 'الدرس الأول',
    2: 'الدرس الثاني',
    3: 'الدرس الثالث',
    4: 'الدرس الرابع',
    11: 'الدرس الحادي عشر',
    12: 'الدرس الثاني عشر',
    13: 'الدرس الثالث عشر',
    20: 'الدرس العشرون',
    21: 'الدرس الحادي والعشرون',
    23: 'الدرس الثالث والعشرون',
    30: 'الدرس الثلاثون',
    33: 'الدرس الثالث والثلاثون',
    43: 'الدرس الثالث والأربعون',
    53: 'الدرس الثالث والخمسون',
    63: 'الدرس الثالث والستون',
    73: 'الدرس الثالث والسبعون',
    83: 'الدرس الثالث والثمانون',
    91: 'الدرس الحادي والتسعون',
  };
  return [
    for (final e in rows.entries)
      _lecture(e.key, {'ar': e.value, 'en': 'Dars ${_p2(e.key)}'}),
  ];
}

/// "c12" / "l36" labels: chapters by chapter number, lectures by global
/// lecture number, in result order.
List<String> _ids(LectureSearchResult r) => [
      for (final h in r.chapters) 'c${h.item.number}',
      for (final h in r.lectures) 'l${h.item.number}',
    ];

List<String> _search(
  String query, {
  required List<Chapter> chapters,
  required List<Lecture> lectures,
}) =>
    _ids(searchLectures(query, chapters: chapters, lectures: lectures));

List<String> _lecturesOfClass(int c) => [
      for (final l in _urduLectures())
        if (l.chapterId == 'class-${_p2(c)}') 'l${l.number}',
    ];

/// The visible substrings a hit highlights in [field], read back out of the
/// ORIGINAL title.
List<String> _spanTexts(SearchHit<dynamic> hit, String field, String title) => [
      for (final s in hit.titleSpans[field] ?? const <MatchSpan>[]) s.of(title),
    ];

SearchHit<Lecture> _soleLecture(String query, List<Lecture> lectures) {
  final r = searchLectures(query, chapters: const [], lectures: lectures);
  expect(r.lectures, hasLength(1), reason: query);
  return r.lectures.isEmpty ? fail('no hit for "$query"') : r.lectures.single;
}

void main() {
  final urduChapters = _urduChapters();
  final urduLectures = _urduLectures();
  final arabicLectures = _arabicLectures();

  List<String> urdu(String q) =>
      _search(q, chapters: urduChapters, lectures: urduLectures);
  List<String> arabic(String q) =>
      _search(q, chapters: const [], lectures: arabicLectures);

  group('fixture sanity (mirrors the real catalogues)', () {
    test('Urdu: 15 classes, 50 lectures, Class 12 = lectures 36-40', () {
      expect(urduChapters, hasLength(15));
      expect(urduLectures, hasLength(50));
      expect(_lecturesOfClass(12), ['l36', 'l37', 'l38', 'l39', 'l40']);
      expect(urduLectures[11].title['en'], 'Class 05 — Part 01');
    });
  });

  group('normalizeSearchText', () {
    final table = <String, (String, String)>{
      'case-fold': ('CLASS Dars', 'class dars'),
      'harakat stripped': ('اَلدَّرْسُ', 'الدرس'),
      'dagger alef stripped': ('الرَّحْمٰن', 'الرحمن'),
      'tatweel stripped': ('الـــدرس', 'الدرس'),
      'Persian yeh -> Arabic yeh': ('التوحید', 'التوحيد'),
      'Persian kaf -> Arabic kaf': ('کتاب', 'كتاب'),
      'heh goal -> heh': ('اللہ', 'الله'),
      'do-chashmi heh -> heh': ('اللھ', 'الله'),
      'alef hamza above': ('أول', 'اول'),
      'alef hamza below': ('إصلاح', 'اصلاح'),
      'alef madda': ('آخر', 'اخر'),
      'ASCII digits kept': ('12', '12'),
      'Arabic-Indic digits': ('١٢', '12'),
      'Extended Arabic-Indic digits': ('۱۲', '12'),
      'ZWNJ dropped': ('حصہ‌۰۲', 'حصه02'),
    };
    table.forEach((name, io) {
      test(name, () => expect(normalizeSearchText(io.$1), io.$2));
    });

    test('teh marbuta is preserved, not unified with heh', () {
      expect(
        normalizeSearchText('الصلاة'),
        isNot(normalizeSearchText('الصلاه')),
      );
      expect(normalizeSearchText('ة'), 'ة');
    });
  });

  group('tokenizeSearchText', () {
    test('splits on whitespace and dash separators, offsets are original', () {
      const s = 'Class 12 — Part 01';
      final tokens = tokenizeSearchText(s);
      expect(
        [for (final t in tokens) t.normalized],
        ['class', '12', 'part', '01'],
      );
      expect(
        [for (final t in tokens) s.substring(t.start, t.end)],
        ['Class', '12', 'Part', '01'],
      );
    });

    test('hyphen, en dash, em dash and Arabic comma all separate', () {
      expect(
        [for (final t in tokenizeSearchText('a-b–c—d،e')) t.normalized],
        ['a', 'b', 'c', 'd', 'e'],
      );
    });

    test('collapses repeated whitespace/separators; no empty tokens', () {
      expect(
        [for (final t in tokenizeSearchText('  a   —  - b  ')) t.normalized],
        ['a', 'b'],
      );
    });

    test('harakat do not split or shift a token: span covers whole word', () {
      const s = 'الدَّرْسُ الثَّالِثُ';
      final tokens = tokenizeSearchText(s);
      expect(tokens, hasLength(2));
      expect(s.substring(tokens[0].start, tokens[0].end), 'الدَّرْسُ');
      expect(s.substring(tokens[1].start, tokens[1].end), 'الثَّالِثُ');
      expect(tokens[1].normalized, 'الثالث');
    });

    test('digits in any script normalise to ASCII tokens', () {
      expect(
        [for (final t in tokenizeSearchText('12 ١٢ ۱۲ ۰۲')) t.normalized],
        ['12', '12', '12', '02'],
      );
    });
  });

  group('empty query', () {
    for (final q in ['', '   ', '\t\n', ' — ', '-', '،']) {
      test('"${q.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}"', () {
        final r = searchLectures(
          q,
          chapters: urduChapters,
          lectures: urduLectures,
        );
        expect(r.isEmptyQuery, isTrue);
        expect(r.chapters, isEmpty);
        expect(r.lectures, isEmpty);
        expect(r.length, 0);
      });
    }

    test('a real query with no matches is NOT an empty query', () {
      final r = searchLectures(
        'zzzz',
        chapters: urduChapters,
        lectures: urduLectures,
      );
      expect(r.isEmptyQuery, isFalse);
      expect(r.length, 0);
    });
  });

  group('numeric tokens (Urdu edition)', () {
    test('"12" -> Class 12, its 5 parts, and lecture 12 (7 results)', () {
      final r = searchLectures(
        '12',
        chapters: urduChapters,
        lectures: urduLectures,
      );
      expect(r.length, 7);
      expect(_ids(r), ['c12', 'l12', 'l36', 'l37', 'l38', 'l39', 'l40']);
    });

    // Every spelling of "twelve" is the same query.
    for (final q in ['12', '۱۲', '١٢', '012', '۰۱۲', ' 12 ']) {
      test('"$q" == "12"', () {
        expect(urdu(q), urdu('12'));
        expect(urdu(q), hasLength(7));
      });
    }

    test('"2" == "02" == "۰۲" == "٠٢"', () {
      final base = urdu('2');
      expect(base, isNotEmpty);
      for (final q in ['02', '۰۲', '٠٢', '002']) {
        expect(urdu(q), base, reason: q);
      }
    });

    test('"1" never matches 12 (whole-token numeric equality)', () {
      final r = urdu('1');
      expect(r, contains('c1'));
      expect(r, contains('l1'));
      expect(r, isNot(contains('c12')));
      expect(r, isNot(contains('c11')));
      expect(r, isNot(contains('l37'))); // Class 12 - Part 02
      expect(r, isNot(contains('l11'))); // global 11 = Class 04 - Part 03
    });

    test('"1" matches neither chapter 12 nor lecture 12 on their numbers', () {
      final chapters = [
        _chapter(12, {'en': 'Twelve'}),
      ];
      final lectures = [
        _lecture(12, {'en': 'Intro'}),
      ];
      expect(_search('1', chapters: chapters, lectures: lectures), isEmpty);
      expect(
        _search('12', chapters: chapters, lectures: lectures),
        ['c12', 'l12'],
      );
    });

    test('a bare number matches the global lecture number (badge) alone', () {
      // Lecture 12 is "Class 05 - Part 01": no "12" in any of its titles.
      expect(urdu('12'), contains('l12'));
      expect(urdu('50'), ['l50']);
    });

    test('a bare number matches a chapter number alone', () {
      final chapters = [
        _chapter(7, {'en': 'Seventh'}),
      ];
      expect(_search('7', chapters: chapters, lectures: []), ['c7']);
    });

    test('number 0 (missing in the catalogue) is not a real match', () {
      final chapters = [
        _chapter(0, {'en': 'Intro'}),
      ];
      final lectures = [
        _lecture(0, {'en': 'Intro'}),
      ];
      expect(_search('0', chapters: chapters, lectures: lectures), isEmpty);
    });

    test('digit forms inside titles compare numerically', () {
      final lectures = [
        _lecture(90, {'en': 'Part ٠٣'}),
        _lecture(91, {'en': 'Part ۰۳'}),
        _lecture(92, {'en': 'Part 13'}),
      ];
      expect(_search('3', chapters: [], lectures: lectures), ['l90', 'l91']);
    });
  });

  group('qualifiers (Urdu edition)', () {
    final class12 = ['c12', ..._lecturesOfClass(12)];

    for (final q in [
      'class 12',
      'Class 12',
      'CLASS 12',
      'class 012',
      'dars 12',
      'Dars ۱۲',
      'درس ۱۲',
      'درس 12',
      'درس ١٢',
    ]) {
      test('"$q" -> chapter-number only', () {
        expect(urdu(q), class12);
      });
    }

    test('"class12" (no space) is plain text, not a qualifier pair', () {
      expect(urdu('class12'), isEmpty);
    });

    test('"class 12" excludes lecture 12 (Class 05 - Part 01)', () {
      expect(urdu('class 12'), isNot(contains('l12')));
    });

    test('"class 1" -> Class 1 and its two parts only', () {
      expect(urdu('class 1'), ['c1', 'l1', 'l2']);
    });

    test('"class 5" is chapter-number only, not lecture 5', () {
      expect(urdu('class 5'), ['c5', ..._lecturesOfClass(5)]);
    });

    final everyPart2 = [
      for (var c = 1; c <= 15; c++) _lecturesOfClass(c)[1],
    ];
    for (final q in [
      'part 2',
      'Part 02',
      'PART 2',
      'Hissa 2',
      'hissa 02',
      'حصہ ۲',
      'حصہ ۰۲',
      'حصہ 2',
      'حصّہ ۲', // with shadda
    ]) {
      test('"$q" -> every Part 02, lectures only', () {
        final r = urdu(q);
        expect(r, everyPart2);
        expect(r, hasLength(15));
      });
    }

    test('"part 5" -> only classes that have a fifth part', () {
      expect(
        urdu('part 5'),
        [_lecturesOfClass(12)[4], _lecturesOfClass(14)[4]],
      );
    });

    test('"part 6" -> nothing', () {
      expect(urdu('part 6'), isEmpty);
    });

    test('part qualifier never matches chapters or global lecture numbers', () {
      // Lecture 2 is global number 2 but Class 01 - Part 02 is what matches.
      final r = urdu('part 1');
      expect(r.where((i) => i.startsWith('c')), isEmpty);
      expect(r, hasLength(15));
    });

    test('qualifiers combine: "class 12 part 2" -> that one lecture', () {
      expect(urdu('class 12 part 2'), ['l37']);
      expect(urdu('درس ۱۲ حصہ ۲'), ['l37']);
      expect(urdu('Dars 12 — Hissa 02'), ['l37']);
    });

    test('a bare number AND a part qualifier: "12 part 2"', () {
      expect(urdu('12 part 2'), ['l37']);
    });

    test('a qualifier keyword without a number is a plain text token', () {
      expect(urdu('class'), [
        for (var c = 1; c <= 15; c++) 'c$c',
        for (var l = 1; l <= 50; l++) 'l$l',
      ]);
      // "hissa" only appears in lecture titles.
      expect(urdu('hissa'), [for (var l = 1; l <= 50; l++) 'l$l']);
      expect(urdu('class abc'), isEmpty);
    });

    test('chapter-qualified lookup uses the lecture\'s parent chapter', () {
      // Lecture 12's own number is 12, but its chapter is Class 05.
      expect(urdu('class 5'), contains('l12'));
      expect(urdu('class 12'), isNot(contains('l12')));
    });
  });

  group('text tokens', () {
    test('substring, case-folded, across every title field', () {
      // "dars" lives only in the roman field; UI language is irrelevant.
      expect(urdu('dars'), [
        for (var c = 1; c <= 15; c++) 'c$c',
        for (var l = 1; l <= 50; l++) 'l$l',
      ]);
      expect(urdu('DARS'), urdu('dars'));
      expect(urdu('hiss'), [for (var l = 1; l <= 50; l++) 'l$l']);
    });

    test('Urdu-script query matches via the ur field', () {
      expect(urdu('حصہ'), [for (var l = 1; l <= 50; l++) 'l$l']);
    });

    test('multiple tokens AND together', () {
      expect(urdu('dars hissa'), [for (var l = 1; l <= 50; l++) 'l$l']);
      expect(urdu('dars zzz'), isEmpty);
      expect(urdu('12 hissa'), ['l12', 'l36', 'l37', 'l38', 'l39', 'l40']);
    });

    test('tokens may be satisfied by different title fields', () {
      // "class" is only in `en`, "hissa" only in `roman`.
      expect(urdu('class hissa'), [for (var l = 1; l <= 50; l++) 'l$l']);
    });

    test('a text token does not match inside a numeric token', () {
      expect(urdu('zero'), isEmpty);
    });

    test('results keep catalogue order, chapters before lectures', () {
      final reversed = urduLectures.reversed.toList();
      expect(
        _search('class 12', chapters: urduChapters, lectures: reversed),
        ['c12', 'l40', 'l39', 'l38', 'l37', 'l36'],
      );
    });
  });

  group('Arabic edition (no chapters)', () {
    const thirds = [
      'l3', 'l13', 'l23', 'l33', 'l43', 'l53', 'l63', 'l73', 'l83', //
    ];

    test('"الثالث" substring-matches every "third" ordinal', () {
      expect(arabic('الثالث'), thirds);
    });

    test('harakat in the query are ignored', () {
      expect(arabic('الثَّالِث'), thirds);
    });

    test('a partial word still matches (substring)', () {
      expect(arabic('ثالث'), thirds);
    });

    test('hamza forms are unified', () {
      expect(arabic('الاول'), ['l1']);
      expect(arabic('الأول'), ['l1']);
      expect(arabic('الإول'), ['l1']);
      expect(arabic('الاربعون'), ['l43']);
    });

    test('ordinals are NOT converted to numbers', () {
      // "الثالث" does not behave like "3": the number only hits lecture 3.
      expect(arabic('3'), ['l3']);
      expect(arabic('13'), ['l13']);
    });

    test('multi-token ordinal query ANDs substrings', () {
      // Substring semantics: "عشر" also sits inside "والعشرون" (23).
      expect(arabic('الثالث عشر'), ['l13', 'l23']);
      expect(arabic('الثاني عشر'), ['l12']);
    });

    test('"dars 3" / "درس 3": chapterless lectures qualify by own number', () {
      expect(arabic('dars 3'), ['l3']);
      expect(arabic('درس ٣'), ['l3']);
      expect(arabic('الدرس 13'), ['l13']);
    });

    test('no part titles -> a part qualifier finds nothing', () {
      expect(arabic('part 3'), isEmpty);
    });

    test('the Latin title is searchable too', () {
      expect(arabic('Dars 03'), ['l3']);
      expect(arabic('dars'), [for (final l in arabicLectures) 'l${l.number}']);
    });
  });

  group('letter folding in search', () {
    test('teh marbuta vs heh are NOT unified', () {
      final lectures = [
        _lecture(1, {'ar': 'الصلاة'}),
        _lecture(2, {'ar': 'الصلاه'}),
      ];
      expect(_search('صلاة', chapters: [], lectures: lectures), ['l1']);
      expect(_search('صلاه', chapters: [], lectures: lectures), ['l2']);
    });

    test('heh forms are unified (ه / ہ / ھ)', () {
      final lectures = [
        _lecture(1, {'ar': 'الله'}),
        _lecture(2, {'ur': 'اللہ'}),
        _lecture(3, {'ur': 'اللھ'}),
      ];
      for (final q in ['الله', 'اللہ', 'اللھ']) {
        expect(
          _search(q, chapters: [], lectures: lectures),
          ['l1', 'l2', 'l3'],
        );
      }
    });

    test('kaf and yeh forms are unified', () {
      final lectures = [
        _lecture(1, {'ar': 'كتاب التوحيد'}),
        _lecture(2, {'ur': 'کتاب التوحید'}),
      ];
      for (final q in ['كتاب', 'کتاب', 'التوحيد', 'التوحید']) {
        expect(_search(q, chapters: [], lectures: lectures), ['l1', 'l2']);
      }
    });

    test('tatweel and harakat in a TITLE are ignored', () {
      final lectures = [
        _lecture(1, {'ar': 'الدَّرْسُ الــثَّالِثُ'}),
      ];
      expect(_search('الثالث', chapters: [], lectures: lectures), ['l1']);
      expect(_search('الدرس', chapters: [], lectures: lectures), ['l1']);
    });

    test('missing / non-string title values never throw', () {
      final lectures = [
        _lecture(1, {'en': 'Alpha', 'ur': null, 'roman': 5}),
        _lecture(2, {}),
      ];
      expect(_search('alpha', chapters: [], lectures: lectures), ['l1']);
    });
  });

  group('highlight spans (original-string token offsets)', () {
    SearchHit<Chapter> chapterHit(String q, int number) => searchLectures(
          q,
          chapters: urduChapters,
          lectures: urduLectures,
        ).chapters.firstWhere(
              (h) => h.item.number == number,
              orElse: () => fail('no chapter hit $number for "$q"'),
            );

    SearchHit<Lecture> lectureHit(String q, int number) => searchLectures(
          q,
          chapters: urduChapters,
          lectures: urduLectures,
        ).lectures.firstWhere(
              (h) => h.item.number == number,
              orElse: () => fail('no lecture hit $number for "$q"'),
            );

    test('"12" highlights the visible number token in each title field', () {
      final hit = chapterHit('12', 12);
      expect(_spanTexts(hit, 'en', 'Class 12'), ['12']);
      expect(_spanTexts(hit, 'ur', 'درس ۱۲'), ['۱۲']);
      expect(_spanTexts(hit, 'roman', 'Dars 12'), ['12']);
    });

    test('only the matching number token is highlighted, not other numbers',
        () {
      final hit = lectureHit('12', 36);
      expect(_spanTexts(hit, 'en', 'Class 12 — Part 01'), ['12']);
      expect(
        _spanTexts(hit, 'ur', 'درس ۱۲ — حصہ ۰۱'),
        ['۱۲'],
      );
    });

    test('a match on the lecture number alone has no title spans', () {
      final hit = lectureHit('12', 12);
      expect(hit.titleSpans.values.expand((s) => s), isEmpty);
    });

    test('"Hissa 2" highlights keyword + number in every language', () {
      final hit = lectureHit('Hissa 2', 37);
      expect(_spanTexts(hit, 'en', 'Class 12 — Part 02'), ['Part', '02']);
      expect(_spanTexts(hit, 'roman', 'Dars 12 — Hissa 02'), ['Hissa', '02']);
      expect(
        _spanTexts(hit, 'ur', 'درس ۱۲ — حصہ ۰۲'),
        ['حصہ', '۰۲'],
      );
    });

    test('"class 12" highlights the chapter keyword and number', () {
      final hit = chapterHit('class 12', 12);
      expect(_spanTexts(hit, 'en', 'Class 12'), ['Class', '12']);
      expect(_spanTexts(hit, 'ur', 'درس ۱۲'), ['درس', '۱۲']);
    });

    test('text matches highlight the whole original token', () {
      const title = 'الدَّرْسُ الثَّالِثُ';
      final lectures = [
        _lecture(3, {'ar': title}),
      ];
      final hit = _soleLecture('ثالث', lectures);
      // Not a harakat-split fragment: the full token as displayed.
      expect(_spanTexts(hit, 'ar', title), ['الثَّالِثُ']);
      expect(hit.titleSpans['ar']?.single.start, title.indexOf('الثَّالِثُ'));
    });

    test('offsets stay correct when harakat precede the match', () {
      const title = 'الدَّرْسُ ١٢';
      final lectures = [
        _lecture(5, {'ar': title}),
      ];
      final hit = _soleLecture('12', lectures);
      expect(hit.titleSpans['ar'], isNotNull);
      final span = hit.titleSpans['ar']!.single;
      expect(span.start, title.indexOf('١٢'));
      expect(span.of(title), '١٢');
    });

    test('spans are de-duplicated and sorted by position', () {
      final hit = chapterHit('class 12 class', 12);
      final en = hit.titleSpans['en'] ?? const <MatchSpan>[];
      expect(en, hasLength(2)); // Class, 12 — "class" twice yields one span
      expect(en.first.start, lessThan(en.last.start));
      expect(_spanTexts(hit, 'en', 'Class 12'), ['Class', '12']);
    });

    test('fields without a match are absent from titleSpans', () {
      final lectures = [
        _lecture(1, {'en': 'Alpha', 'ur': 'بیٹا'}),
      ];
      final hit = _soleLecture('alp', lectures);
      expect(hit.titleSpans.keys, ['en']);
    });
  });
}
