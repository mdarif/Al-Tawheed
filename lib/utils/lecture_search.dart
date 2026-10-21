// Pure, in-memory matcher behind the Search screen (release 2.4.2, B1c).
//
// No Flutter, no providers, no I/O: give it the query and the already-loaded
// catalogue's chapters and lectures, get back ordered hits plus the title
// spans to highlight. Catalogue sizes are 50 (Urdu) and 91 (Arabic) lectures,
// so every call is a plain linear scan — no index, nothing to persist.
//
// Semantics (docs/plans/release-2.5-ia-polish-plan.md §Search semantics):
//
// * Every title field of a chapter/lecture (`en`, `ur`, `roman`, `ar`, ...) is
//   searched, whatever the UI language is.
// * Strings are TOKENISED FIRST, in their original form; only each token is
//   then normalised for comparison. A match highlights the whole original
//   token. Normalised offsets are never mapped back onto source text —
//   stripping harakat shifts them and would split Arabic ligatures.
// * Numeric tokens compare numerically as whole tokens (`2` = `02` = `۰۲`;
//   `1` never matches `12`). A bare number matches a chapter's number, a
//   number inside any title, and the global lecture number shown on the badge.
// * A qualifier keyword directly followed by a number narrows it to one role.
//   Chapter keywords: `class`, `dars`, `درس`, `الدرس` -> the CHAPTER number
//   (a lecture qualifies through its parent chapter; a lecture with no
//   resolvable parent chapter, as in the Arabic edition, qualifies by its own
//   number, because there each lecture is the "dars"). Part keywords: `part`,
//   `hissa`, `حصہ` -> the PART number (a lecture whose title reads
//   "<part keyword> <n>"; chapters never match).
// * Any other token is a substring match against title tokens. All query
//   terms must match (AND), though different terms may match in different
//   title fields. Arabic ordinals are substring matches ("الثالث" hits 3, 13,
//   23, ...), not ordinal-to-number conversion.
// * Results: chapter hits first, then lecture hits, each in the order the
//   caller supplied (catalogue order).

import 'package:myapp/models/catalog.dart';

/// A half-open `[start, end)` range of UTF-16 code units in an ORIGINAL
/// (unnormalised) title string. Always covers a whole token.
class MatchSpan {
  final int start;
  final int end;

  const MatchSpan(this.start, this.end);

  /// The highlighted text, read back out of the original [source] string.
  String of(String source) => source.substring(start, end);

  @override
  bool operator ==(Object other) =>
      other is MatchSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MatchSpan($start, $end)';
}

/// One token of a string: its range in the original, and its normalised form.
class SearchToken {
  final int start;
  final int end;
  final String normalized;

  const SearchToken(this.start, this.end, this.normalized);

  @override
  String toString() => 'SearchToken($start, $end, $normalized)';
}

/// A matched chapter or lecture plus what to highlight.
class SearchHit<T> {
  final T item;

  /// Title field key (`en`, `ur`, `roman`, `ar`, ...) -> spans to highlight in
  /// that field's ORIGINAL string, sorted by position, without duplicates.
  /// Fields with nothing to highlight are absent; a hit that matched only on
  /// a number the title does not spell out (the global lecture number) has an
  /// empty map.
  final Map<String, List<MatchSpan>> titleSpans;

  const SearchHit(this.item, this.titleSpans);
}

class LectureSearchResult {
  /// True when the query had no searchable token (empty, whitespace or only
  /// separators). Distinct from "searched and found nothing": the UI shows its
  /// idle state for the former and "no results" for the latter.
  final bool isEmptyQuery;
  final List<SearchHit<Chapter>> chapters;
  final List<SearchHit<Lecture>> lectures;

  const LectureSearchResult({
    required this.isEmptyQuery,
    required this.chapters,
    required this.lectures,
  });

  int get length => chapters.length + lectures.length;
}

// ── Normalisation & tokenisation ────────────────────────────────────────────

/// Characters that belong inside a token: letters, combining marks (harakat),
/// digits of any script, apostrophes (Ta'ala) and the zero-width joiners used
/// in Urdu/Persian shaping. Everything else — whitespace, dashes, punctuation
/// — separates tokens.
final RegExp _tokenChar = RegExp(
  r"[\p{L}\p{M}\p{N}'’‌‍]",
  unicode: true,
);

final RegExp _separators = RegExp(r'[\s\-‐-―]+');

final RegExp _allDigits = RegExp(r'^[0-9]+$');

bool _isStripped(int r) =>
    r == 0x0640 || // tatweel
    r == 0x200C || // zero-width non-joiner
    r == 0x200D || // zero-width joiner
    (r >= 0x0610 && r <= 0x061A) || // Quranic annotation signs
    (r >= 0x064B && r <= 0x065F) || // harakat, shadda, sukun, ...
    r == 0x0670 || // dagger alef
    (r >= 0x06D6 && r <= 0x06DC) || // Quranic marks
    (r >= 0x06DF && r <= 0x06E4) ||
    r == 0x06E7 ||
    r == 0x06E8 ||
    (r >= 0x06EA && r <= 0x06ED) ||
    (r >= 0x08D3 && r <= 0x08E1) ||
    (r >= 0x08E3 && r <= 0x08FF);

/// Case-folds [input], strips harakat and tatweel, unifies the Urdu/Persian
/// letter forms with their Arabic counterparts (ی->ي, ک->ك, ہ/ھ->ه) and the
/// hamza-carrying alefs (أ/إ/آ->ا), maps ASCII, Arabic-Indic (٠-٩) and
/// Extended Arabic-Indic (۰-۹) digits to ASCII, and collapses whitespace and
/// dash separators to single spaces.
///
/// Arabic teh marbuta (ة) is deliberately PRESERVED: it is a distinct letter,
/// and folding it into ه would produce false hits.
String normalizeSearchText(String input) {
  final out = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    if (_isStripped(r)) continue;
    if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + r - 0x06F0);
    } else {
      out.writeCharCode(
        switch (r) {
          0x06CC => 0x064A, // ی  -> ي
          0x06A9 => 0x0643, // ک  -> ك
          0x06C1 || 0x06BE => 0x0647, // ہ / ھ -> ه
          0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // آ أ إ ٱ -> ا
          _ => r,
        },
      );
    }
  }
  return out.toString().replaceAll(_separators, ' ').trim();
}

/// Splits [input] into tokens. Offsets index the ORIGINAL string and each
/// token spans the whole visible word (harakat included); only the
/// [SearchToken.normalized] form is normalised.
List<SearchToken> tokenizeSearchText(String input) {
  final tokens = <SearchToken>[];
  var offset = 0;
  int? start;
  for (final r in input.runes) {
    final width = r > 0xFFFF ? 2 : 1;
    if (_tokenChar.hasMatch(String.fromCharCode(r))) {
      start ??= offset;
    } else if (start != null) {
      _addToken(tokens, input, start, offset);
      start = null;
    }
    offset += width;
  }
  if (start != null) _addToken(tokens, input, start, offset);
  return tokens;
}

void _addToken(List<SearchToken> out, String input, int start, int end) {
  final normalized = normalizeSearchText(input.substring(start, end));
  // A token made only of stripped characters (a lone tatweel) is not a word.
  if (normalized.isEmpty) return;
  out.add(SearchToken(start, end, normalized));
}

// ── Query model ─────────────────────────────────────────────────────────────

/// Qualifier keywords, already normalised (so `حصہ` appears as `حصه`).
const Set<String> _chapterKeywords = {'class', 'dars', 'درس', 'الدرس'};
const Set<String> _partKeywords = {'part', 'hissa', 'حصه'};

/// `2`, `02`, `۰۲` all canonicalise to `2`; `0`/`00` to `0`.
String _canonicalNumber(String digits) {
  final stripped = digits.replaceFirst(RegExp(r'^0+(?=[0-9])'), '');
  return stripped;
}

sealed class _Term {
  const _Term();
}

class _TextTerm extends _Term {
  final String text;
  const _TextTerm(this.text);
}

class _NumberTerm extends _Term {
  final String number;
  const _NumberTerm(this.number);
}

class _ChapterTerm extends _Term {
  final String number;
  const _ChapterTerm(this.number);
}

class _PartTerm extends _Term {
  final String number;
  const _PartTerm(this.number);
}

List<_Term> _parseQuery(List<SearchToken> tokens) {
  final terms = <_Term>[];
  var i = 0;
  while (i < tokens.length) {
    final t = tokens[i].normalized;
    final next = i + 1 < tokens.length ? tokens[i + 1].normalized : null;
    final nextIsNumber = next != null && _allDigits.hasMatch(next);
    if (nextIsNumber && _chapterKeywords.contains(t)) {
      terms.add(_ChapterTerm(_canonicalNumber(next)));
      i += 2;
    } else if (nextIsNumber && _partKeywords.contains(t)) {
      terms.add(_PartTerm(_canonicalNumber(next)));
      i += 2;
    } else if (_allDigits.hasMatch(t)) {
      terms.add(_NumberTerm(_canonicalNumber(t)));
      i++;
    } else {
      terms.add(_TextTerm(t));
      i++;
    }
  }
  return terms;
}

// ── Matching ────────────────────────────────────────────────────────────────

/// One title field, tokenised once per search.
class _Field {
  final String key;
  final List<SearchToken> tokens;
  const _Field(this.key, this.tokens);
}

/// What a term is matched against: a chapter or a lecture, tokenised.
class _Subject {
  final List<_Field> fields;

  /// The number a chapter-qualified term compares with, or 0 for none.
  final int chapterNumber;

  /// The global lecture number for lectures, the chapter number for chapters.
  final int ownNumber;
  final bool isLecture;

  const _Subject({
    required this.fields,
    required this.chapterNumber,
    required this.ownNumber,
    required this.isLecture,
  });
}

List<_Field> _fieldsOf(Map<String, dynamic> title) => [
      for (final e in title.entries)
        if (e.value is String && (e.value as String).trim().isNotEmpty)
          _Field(e.key, tokenizeSearchText(e.value as String)),
    ];

bool _isNumber(SearchToken t, String canonical) =>
    _allDigits.hasMatch(t.normalized) &&
    _canonicalNumber(t.normalized) == canonical;

bool _numberIs(int number, String canonical) =>
    number > 0 && number.toString() == canonical;

typedef _Spans = Map<String, Map<int, MatchSpan>>;

void _addSpan(_Spans spans, String field, SearchToken t) {
  (spans[field] ??= {})[t.start] = MatchSpan(t.start, t.end);
}

/// Adds the (keyword, number) token pairs of [subject] whose number equals
/// [canonical] to [spans]; true when any was found.
bool _addPairs(
  _Subject subject,
  Set<String> keywords,
  String canonical,
  _Spans spans,
) {
  var found = false;
  for (final f in subject.fields) {
    for (var i = 0; i + 1 < f.tokens.length; i++) {
      if (keywords.contains(f.tokens[i].normalized) &&
          _isNumber(f.tokens[i + 1], canonical)) {
        _addSpan(spans, f.key, f.tokens[i]);
        _addSpan(spans, f.key, f.tokens[i + 1]);
        found = true;
      }
    }
  }
  return found;
}

/// Whether [subject] satisfies [term]; matched title tokens are added to
/// [spans].
bool _matches(_Term term, _Subject subject, _Spans spans) {
  switch (term) {
    case _TextTerm(:final text):
      var found = false;
      for (final f in subject.fields) {
        for (final t in f.tokens) {
          if (t.normalized.contains(text)) {
            _addSpan(spans, f.key, t);
            found = true;
          }
        }
      }
      return found;
    case _NumberTerm(:final number):
      var found = _numberIs(subject.ownNumber, number);
      for (final f in subject.fields) {
        for (final t in f.tokens) {
          if (_isNumber(t, number)) {
            _addSpan(spans, f.key, t);
            found = true;
          }
        }
      }
      return found;
    case _ChapterTerm(:final number):
      if (!_numberIs(subject.chapterNumber, number)) return false;
      _addPairs(subject, _chapterKeywords, number, spans);
      return true;
    case _PartTerm(:final number):
      return subject.isLecture &&
          _addPairs(subject, _partKeywords, number, spans);
  }
}

/// Matches [subject] against every term (AND). Returns the highlight spans, or
/// null when any term fails.
Map<String, List<MatchSpan>>? _matchAll(List<_Term> terms, _Subject subject) {
  final spans = <String, Map<int, MatchSpan>>{};
  for (final term in terms) {
    if (!_matches(term, subject, spans)) return null;
  }
  return {
    for (final e in spans.entries)
      e.key: (e.value.values.toList()
        ..sort((a, b) => a.start.compareTo(b.start))),
  };
}

/// Searches [chapters] and [lectures] for [query].
///
/// Returns chapter hits, then lecture hits, each in the order given. A query
/// with no searchable token returns no hits and `isEmptyQuery: true`.
LectureSearchResult searchLectures(
  String query, {
  required List<Chapter> chapters,
  required List<Lecture> lectures,
}) {
  final tokens = tokenizeSearchText(query);
  if (tokens.isEmpty) {
    return const LectureSearchResult(
      isEmptyQuery: true,
      chapters: [],
      lectures: [],
    );
  }
  final terms = _parseQuery(tokens);
  final chapterById = {for (final c in chapters) c.id: c};

  final chapterHits = <SearchHit<Chapter>>[];
  for (final c in chapters) {
    final spans = _matchAll(
      terms,
      _Subject(
        fields: _fieldsOf(c.title),
        chapterNumber: c.number,
        ownNumber: c.number,
        isLecture: false,
      ),
    );
    if (spans != null) chapterHits.add(SearchHit(c, spans));
  }

  final lectureHits = <SearchHit<Lecture>>[];
  for (final l in lectures) {
    final parent = chapterById[l.chapterId];
    final spans = _matchAll(
      terms,
      _Subject(
        fields: _fieldsOf(l.title),
        // No resolvable parent (Arabic edition): the lecture is its own class.
        chapterNumber: parent?.number ?? l.number,
        ownNumber: l.number,
        isLecture: true,
      ),
    );
    if (spans != null) lectureHits.add(SearchHit(l, spans));
  }

  return LectureSearchResult(
    isEmptyQuery: false,
    chapters: chapterHits,
    lectures: lectureHits,
  );
}
