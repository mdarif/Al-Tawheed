import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/services/book_service.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);
const _urduSeries = SeriesConfig.legacyUrduFallback;

// The reader's markup (see book_reader_screen): {verse}, ((hadith)),
// [citation]. It renders `{`/`}` AS these ornate parens, and the Urdu print
// also uses them by hand — as general brackets around translator's glosses
// (﴿شرک سے﴾, ﴿کڑا﴾). Both are legitimate; what is never legitimate is an
// unmatched or reversed one.
const _ornateOpen = '\u{FD3F}'; // ﴿
const _ornateClose = '\u{FD3E}'; // ﴾

/// Reports every position where the ornate parens don't nest: a closer with no
/// opener (which is what a *reversed* pair looks like), or an unclosed opener.
List<String> _malformedOrnateParens(BookChapter chapter) {
  final problems = <String>[];
  final lines = chapter.text.split('\n');
  for (var li = 0; li < lines.length; li++) {
    final line = lines[li];
    var depth = 0;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == _ornateOpen) {
        depth++;
      } else if (c == _ornateClose) {
        depth--;
        if (depth < 0) {
          final from = (i - 30).clamp(0, line.length);
          final to = (i + 30).clamp(0, line.length);
          problems.add('${chapter.id}[$li]: closer before opener near '
              '"…${line.substring(from, to)}…"');
          depth = 0;
        }
      }
    }
    if (depth > 0) {
      problems.add('${chapter.id}[$li]: $depth unclosed $_ornateOpen');
    }
  }
  return problems;
}

/// The Arabic inside each `{āyah}` run, normalised for comparison across
/// editions: tashkeel and tatweel stripped, whitespace removed. The two books
/// vocalise the same passage slightly differently, and that must not read as a
/// difference in the text itself.
///
/// The strip range is deliberately narrow — U+064B–U+0652 (the harakat),
/// U+0670 (superscript alef) and U+06D6–U+06ED (Qur'anic annotation). An
/// earlier, wider version of this regex reached back to U+0610 and silently ate
/// most of the Arabic alphabet, wiping surah names out of the assembler's
/// pairing keys. See gotchas.
List<String> _ayat(BookChapter chapter) => [
      for (final m in RegExp(r'\{([^{}]*)\}').allMatches(chapter.text))
        m.group(1)!.replaceAll(_tashkeel, '').replaceAll(RegExp(r'\s'), ''),
    ];

/// Harakat + superscript alef + Qur'anic annotation marks + tatweel.
///
/// Spelled in explicit codepoints, never as literal glyphs: the literal form is
/// unreadable in an editor and is exactly how the original range grew to eat the
/// alphabet.
final _tashkeel = RegExp(
  '[\u{064B}-\u{0652}\u{0670}\u{06D6}-\u{06ED}\u{0640}]',
);

Future<void> _forEachBook(
  Future<void> Function(String name, BookContent book) body,
) async {
  await body('Arabic', await BookService.instance.loadBook(_arabicSeries));
  await body('Urdu', await BookService.instance.loadBook(_urduSeries));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The Book is hand-transcribed scripture — the Urdu print's Nastaliq text
  // layer is corrupted, so every chapter was read by eye from page scans. Its
  // history includes 168 print-verified corrections and two errors that
  // inverted the meaning of the text. These are the cheap, mechanical
  // invariants; they are not a substitute for scholarly review, but they are
  // the difference between a defect being caught here and being read by a user.
  //
  // Do NOT weaken these to make a content change pass. That is how the previous
  // Urdu assertions ("chapters is not empty") ended up guarding nothing.
  // Guards the guard. A tashkeel range that reaches back to U+0610 covers most
  // of the Arabic alphabet; when the assembler's did, it wiped surah names out
  // of its pairing keys and silently mispaired āyāt across the whole book. Any
  // future edit to _tashkeel that repeats that mistake fails here.
  test('the tashkeel strip removes diacritics, never letters', () {
    expect('كِتَابُ التَّوْحِيدِ'.replaceAll(_tashkeel, ''), 'كتاب التوحيد');
    expect('الْعَنْكَبُوتُ'.replaceAll(_tashkeel, ''), 'العنكبوت');
    expect('النَّجْم'.replaceAll(_tashkeel, ''), 'النجم');
    // Letters that live inside the naive-but-wrong U+0610–U+064B range.
    expect('غزت فريا مين'.replaceAll(_tashkeel, ''), 'غزت فريا مين');
  });

  group('bundled Book assets', () {
    test('both editions have 67 contiguous, non-empty chapters', () async {
      await _forEachBook((name, book) async {
        expect(book.chapters, hasLength(67), reason: '$name: chapter count');
        expect(
          book.chapters.map((c) => c.id),
          [for (var i = 1; i <= 67; i++) 'ch-${i.toString().padLeft(2, '0')}'],
          reason: '$name: ids must be ch-01…ch-67, in order, no gaps or dupes',
        );
        for (final chapter in book.chapters) {
          expect(chapter.number, book.chapters.indexOf(chapter) + 1,
              reason: '$name ${chapter.id}: number must match its position',);
          expect(chapter.title.trim(), isNotEmpty,
              reason: '$name ${chapter.id}: empty title',);
          expect(chapter.text.trim(), isNotEmpty,
              reason: '$name ${chapter.id}: empty text',);
        }
      });
    });

    test('the Arabic edition keeps its identity', () async {
      final book = await BookService.instance.loadBook(_arabicSeries);
      expect(book.title, 'كتاب التوحيد');
      expect(book.author, isNotEmpty);
    });

    // Caught 8 real defects the word-by-word print QA missed: ch-59 had six
    // stray closers dumped mid-sentence, ch-21/ch-48/ch-50 had reversed pairs
    // (which render as backwards brackets, since FD3E/FD3F are mirror glyphs).
    test('ornate parens are matched and correctly ordered', () async {
      await _forEachBook((name, book) async {
        final problems = book.chapters.expand(_malformedOrnateParens).toList();
        expect(problems, isEmpty, reason: '$name:\n${problems.join('\n')}');
      });
    });

    // A hadith quote that opens and never closes renders with a dangling «.
    // Balanced per *chapter*, not per line: a quotation may legitimately span
    // several lines (ch-27 does).
    test('hadith guillemets are balanced in every chapter', () async {
      await _forEachBook((name, book) async {
        for (final chapter in book.chapters) {
          expect(
            '«'.allMatches(chapter.text).length,
            '»'.allMatches(chapter.text).length,
            reason: '$name ${chapter.id}: unbalanced « »',
          );
        }
      });
    });

    // The Urdu edition is bilingual by assembly: its Arabic āyāt are INJECTED
    // from book_tawheed-ar.json (the print sets no Arabic at all — it goes
    // straight to the Urdu translation), while the Urdu around them is
    // transcribed from the page. When the injector paired an āyah wrongly it
    // truncated silently: ch-09 got only an-Najm:19 where the print cites
    // 19-23 and its Urdu renders all five verses; ch-40 got the first clause of
    // ar-Ra'd:30 under a translation of the whole verse. 73ca16b fixed three
    // more of these. Nothing caught any of them — a truncated āyah is still
    // well-formed, and ch-40's citation even still matched.
    test('no injected āyah is a truncation of the Arabic edition\'s', () async {
      final arabic = await BookService.instance.loadBook(_arabicSeries);
      final urdu = await BookService.instance.loadBook(_urduSeries);
      final arabicById = {for (final c in arabic.chapters) c.id: c};

      final truncated = <String>[];
      for (final chapter in urdu.chapters) {
        final counterpart = arabicById[chapter.id];
        if (counterpart == null) continue;
        for (final ours in _ayat(chapter)) {
          // Match on a decent prefix so two different āyāt sharing an opening
          // word don't look like a truncation of one another.
          var prefix = ours.length ~/ 2;
          if (prefix < 15) prefix = 15;
          if (prefix > ours.length) prefix = ours.length;

          for (final theirs in _ayat(counterpart)) {
            // A prefix that is materially shorter is a dropped tail, not a
            // different (legitimately shorter) quotation of the same passage.
            if (theirs.length > ours.length + 20 &&
                theirs.startsWith(ours.substring(0, prefix)) &&
                ours != theirs) {
              truncated.add('${chapter.id}: Urdu carries ${ours.length} chars '
                  'of a ${theirs.length}-char āyah — "${ours.substring(0, ours.length.clamp(0, 40))}…"');
            }
          }
        }
      }
      expect(truncated, isEmpty, reason: truncated.join('\n'));
    });

    // The reader paints ANY [ ... ] cyan, as a surah:ayah reference. Two
    // chapters had the translator's own clarifying words in square brackets,
    // so his gloss rendered as though it were a Qur'anic citation — in
    // scripture, that misattributes rather than merely looking wrong. A real
    // citation always carries a number; a gloss never does.
    test('every [bracketed] run is a citation, not prose', () async {
      await _forEachBook((name, book) async {
        final prose = <String>[];
        for (final chapter in book.chapters) {
          for (final m in RegExp(r'\[([^\[\]]+)\]').allMatches(chapter.text)) {
            if (!RegExp(r'[0-9٠-٩۰-۹]')
                .hasMatch(m.group(1)!)) {
              prose.add('$name ${chapter.id}: [${m.group(1)}]');
            }
          }
        }
        expect(prose, isEmpty,
            reason: 'bracketed runs with no number — use ﴿…﴾ for a '
                "translator's gloss:\n${prose.join('\n')}",);
      });
    });
  });
}
