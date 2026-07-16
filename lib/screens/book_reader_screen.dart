import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// The three theme-resolved highlight colours passed down to span building,
/// so the reader doesn't read [BuildContext] inside its text-layout helpers.
typedef _HighlightColors = ({
  Color verse,
  Color citation,
  Color hadith,
  Color masailHeading,
});

class BookReaderScreen extends StatefulWidget {
  final String chapterId;

  const BookReaderScreen({super.key, required this.chapterId});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  PageController? _pageController;
  List<BookChapter> _chapters = const [];
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One-time init: build the pager over all chapters starting at the one the
    // user opened. The book is already loaded by the time the reader is reached.
    if (_pageController == null) {
      final book = context.read<BookProvider>().book;
      if (book == null) return;
      _chapters = book.chapters;
      _currentIndex =
          _chapters.indexWhere((c) => c.id == widget.chapterId).clamp(
                0,
                _chapters.length - 1,
              );
      _pageController = PageController(initialPage: _currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  static const _minFontSize = 14.0;
  static const _maxFontSize = 32.0;
  static const _fontStep = 2.0;

  void _adjustFont(double delta) {
    final reading = context.read<ReadingProvider>();
    final next =
        (reading.bookFontSize + delta).clamp(_minFontSize, _maxFontSize);
    reading.setBookFontSize(next);
  }

  void _showColorKey(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ColorKeySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _pageController;
    if (controller == null || _chapters.isEmpty) {
      return Scaffold(appBar: AppBar());
    }

    final chapter = _chapters[_currentIndex];
    final series = context.watch<SeriesProvider>().currentSeries;
    final fontFamily = series.bookFontFamily;
    final language = series.language;

    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chapter.title,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFamily: fontFamily,
                ),
              ),
              // Long bab titles ellipsize, so the title alone never says WHERE
              // you are. Digits only ("۲ / ۶۷"): unambiguous in every locale and
              // needs no new strings. Rendered in the book font so the numerals
              // take the series' own shapes (Urdu vs Persian differ at 4/5/6/7).
              Text(
                '${localizedDigitsInString('${_currentIndex + 1}', language)}'
                ' / '
                '${localizedDigitsInString('${_chapters.length}', language)}',
                textAlign: TextAlign.right,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.secondaryTextColor,
                  fontFamily: fontFamily,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease_rounded),
            tooltip: context.l10n.bookDecreaseText,
            onPressed: context.watch<ReadingProvider>().bookFontSize >
                    _minFontSize
                ? () => _adjustFont(-_fontStep)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.text_increase_rounded),
            tooltip: context.l10n.bookIncreaseText,
            onPressed: context.watch<ReadingProvider>().bookFontSize <
                    _maxFontSize
                ? () => _adjustFont(_fontStep)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: context.l10n.bookColorKey,
            onPressed: () => _showColorKey(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: context.l10n.bookShareChapter,
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: '${chapter.title}\n\n${chapter.text}'),
            ),
          ),
        ],
      ),
      // SelectionArea wraps the pager (ancestor) so passages stay
      // selectable/copyable via long-press, while the PageView — being the
      // deeper widget — wins horizontal swipes in the gesture arena. That lets
      // both coexist: long-press selects, a horizontal drag turns the page.
      //
      // Horizontal pager — swipe to turn the page like a printed book.
      // reverse:true matches RTL reading order: a left-to-right swipe advances
      // to the next chapter (which sits to the left), right-to-left goes back.
      body: SelectionArea(
        child: PageView.builder(
          controller: controller,
          reverse: true,
          itemCount: _chapters.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, i) => _BookBody(
            text: _chapters[i].text,
            chapterId: _chapters[i].id,
            fontFamily: fontFamily,
            language: language,
          ),
        ),
      ),
      bottomNavigationBar: _ChapterNavBar(
        onPrev: _currentIndex > 0 ? () => _goToPage(_currentIndex - 1) : null,
        onNext: _currentIndex < _chapters.length - 1
            ? () => _goToPage(_currentIndex + 1)
            : null,
      ),
    );
  }
}

class _BookBody extends StatefulWidget {
  final String text;
  final String chapterId;
  final String fontFamily;
  final String language;
  const _BookBody({
    required this.text,
    required this.chapterId,
    required this.fontFamily,
    required this.language,
  });

  @override
  State<_BookBody> createState() => _BookBodyState();
}

class _BookBodyState extends State<_BookBody> {
  bool _initialized = false;
  final _scrollController = ScrollController();
  double _lastOffset = 0;
  late ReadingProvider _reading;

  /// Style-independent parse of [_BookBody.text], computed once per chapter
  /// (see [_parseChapter]). Each entry is a line: null = blank spacer, else a
  /// list of (text, type) runs. Only the [TextStyle] is applied at build time.
  late List<List<(String, int)>?> _parsedLines;

  static final _verseRe = RegExp(r'\{[^}]+\}');
  static final _citationRe = RegExp(r'\[[^\[\]]+\]');
  static final _hadithRe = RegExp(r'\(\([^)]+(?:\)[^)]+)*\)\)');

  // The masāʾil heading ("اس باب کے کچھ اہم مسائل:") opens the closing section
  // of every Urdu chapter — the author's own summary points, as opposed to the
  // quoted āyāt and hadith of the matn above it. It gets a rule + its own
  // colour so the seam is obvious.
  //
  // Matching on the plural مسائل alone is not enough: a few numbered items use
  // the word mid-sentence (ch-01, ch-11). Those always carry the singular
  // مسئلہ, which no heading does — so requiring مسائل WITHOUT مسئلہ isolates
  // exactly one heading in all 67 chapters. That also absorbs the print's own
  // heading variants (missing colon, a space before it, and ch-06's much longer
  // "…عظیم مسائل ہیں، جن میں سب سے اہم مندرجہ ذیل ہیں:"), which a stricter
  // "ends with مسائل:" rule would miss. The Arabic book is matn-only and has no
  // such line, so this is inert there.
  static bool _isMasailHeading(String line) =>
      line.contains('مسائل') && !line.contains('مسئلہ');

  // Quranic verse ornaments — replace the source's ASCII { } so verses render
  // like a printed mushaf: ﴾ at the verse start (rightmost in RTL) and ﴿ at the
  // end (leftmost). These ornate parens are bidi-mirrored inside the RTL run,
  // so the codepoints are the reverse of what their names suggest: the logical
  // opener '{' uses U+FD3F and the closer '}' uses U+FD3E. Escapes keep the
  // source unambiguous under bidi rendering.
  static const _ornateOpen = '\u{FD3F}'; // renders ﴾ at verse start
  static const _ornateClose = '\u{FD3E}'; // renders ﴿ at verse end

  // Hadith (Prophetic narrations) — the source wraps them in ASCII (( )). Arabic
  // typography encloses hadith in angle quotation marks « », so swap the double
  // parens for guillemets. Like the ornaments these are bidi-mirrored in the RTL
  // run, rendering as »نص« with the chevrons embracing the text.
  static const _hadithOpen = '\u{00AB}'; // «  at hadith start
  static const _hadithClose = '\u{00BB}'; // »  at hadith end

  // Parses the whole chapter once into style-independent runs. The regex
  // passes, interval sort, and string rewriting (ornaments, guillemets,
  // Eastern-Arabic digits) depend only on the source text — not on font size or
  // theme colours — so doing this once (not on every rebuild) keeps A−/A+ and
  // light/dark switches cheap. Each line becomes null (a blank spacer) or a
  // list of (text, type) runs.
  List<List<(String, int)>?> _parseChapter(String source) {
    return [
      for (final line in source.split('\n'))
        line.trim().isEmpty ? null : _parseLine(line),
    ];
  }

  // Run types: 0 = plain, 1 = verse, 2 = citation, 3 = hadith,
  // 4 = masāʾil heading. Colours are resolved from the active theme at render
  // time (see [_renderLines]).
  List<(String, int)> _parseLine(String line) {
    // The masāʾil heading is a whole-line unit carrying no inline markup, so it
    // short-circuits the interval parse below.
    if (_isMasailHeading(line)) {
      return [(line, 4)];
    }

    // Digits are localised per-run at render time (by the run's script), so
    // keep the raw text here.
    final text = line;

    final intervals = <(int, int, int)>[];
    for (final m in _verseRe.allMatches(text)) {
      intervals.add((m.start, m.end, 1));
    }
    for (final m in _citationRe.allMatches(text)) {
      intervals.add((m.start, m.end, 2));
    }
    for (final m in _hadithRe.allMatches(text)) {
      intervals.add((m.start, m.end, 3));
    }
    intervals.sort((a, b) => a.$1.compareTo(b.$1));

    final runs = <(String, int)>[];
    int last = 0;
    for (final (start, end, type) in intervals) {
      if (start > last) {
        runs.add((text.substring(last, start), 0));
      }
      var segment = text.substring(start, end);
      if (type == 1) {
        segment =
            segment.replaceAll('{', _ornateOpen).replaceAll('}', _ornateClose);
      } else if (type == 3) {
        // Strip the outer (( )) and wrap in guillemets — inner single parens
        // (e.g. ayah numbers) are left intact.
        segment = _hadithOpen +
            segment.substring(2, segment.length - 2) +
            _hadithClose;
      }
      runs.add((segment, type));
      last = end;
    }
    if (last < text.length) {
      runs.add((text.substring(last), 0));
    }
    return runs;
  }

  Color _colorFor(int type, _HighlightColors colors) => switch (type) {
        1 => colors.verse,
        2 => colors.citation,
        4 => colors.masailHeading,
        _ => colors.hadith,
      };

  // Urdu uses letters (ک گ چ پ ژ ٹ ڈ ڑ ں ھ ہ ی ے) that Qur'anic Arabic never
  // does, so a line's script is unambiguous. Arabic (verses, hadith, narrator
  // prose) renders in Naskh; Urdu (translation, sharah, masā'il) in the series
  // font (Nastaliq), which also needs a larger size and more generous leading.
  static final _urduLetters = RegExp(
    r'[کگچپژٹڈڑںھہیے]',
  );

  // Noto Nastaliq Urdu renders visually larger than Noto Naskh Arabic at the
  // same point size, so Urdu is scaled to sit level with the Arabic matn.
  // Tunable: raise toward 1.0 for larger Urdu, lower for smaller. Nastaliq's
  // tall, sloping glyphs still get generous leading via [_urduHeight].
  static const _urduSizeFactor = 0.78;
  static const _urduHeight = 2.0;
  static const _arabicHeight = 1.8;

  // Applies per-line script (font/size/leading) + theme colours to the
  // precomputed runs — the only per-rebuild work. No regex-heavy parsing here.
  List<Widget> _renderLines(
    TextStyle template,
    double fontSize,
    _HighlightColors colors,
  ) {
    final widgets = <Widget>[];
    for (final runs in _parsedLines) {
      if (runs == null) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      // Line leading follows the taller script present (Nastaliq needs more),
      // so a mixed Urdu-intro + Arabic-āyah line still breathes.
      final height =
          runs.any((r) => _urduLetters.hasMatch(r.$1)) ? _urduHeight : _arabicHeight;

      // The masāʾil heading closes the matn and opens the author's summary
      // points — mark the seam with a rule and extra space above it.
      if (runs.length == 1 && runs.first.$2 == 4) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            child: Divider(height: 1, thickness: 1, color: colors.masailHeading.withValues(alpha: 0.35)),
          ),
        );
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            TextSpan(
              children: [
                for (final (text, type) in runs)
                  _runSpan(text, type, fontSize, height, template, colors),
              ],
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
    return widgets;
  }

  // Font & size are chosen per run by its OWN script — Arabic (Qur'anic āyāt)
  // in Naskh, Urdu in the series font (Nastaliq), scaled to sit level — so a
  // single line can mix an Urdu intro with an Arabic verse. Digits, however,
  // follow the BOOK's language (Urdu numerals throughout an Urdu book, even
  // inside the Arabic āyāt/citations), which is what an Urdu reader expects.
  TextSpan _runSpan(
    String text,
    int type,
    double fontSize,
    double height,
    TextStyle template,
    _HighlightColors colors,
  ) {
    final isUrdu = _urduLetters.hasMatch(text);
    var style = template.copyWith(
      fontFamily: isUrdu ? widget.fontFamily : 'NotoNaskhArabic',
      fontSize: isUrdu ? fontSize * _urduSizeFactor : fontSize,
      height: height,
    );
    if (type != 0) style = style.copyWith(color: _colorFor(type, colors));
    // The masāʾil heading also carries weight — it is a section header, not
    // just another coloured run.
    if (type == 4) style = style.copyWith(fontWeight: FontWeight.w700);
    return TextSpan(
      text: localizedDigitsInString(text, widget.language),
      style: style,
    );
  }

  @override
  void initState() {
    super.initState();
    _parsedLines = _parseChapter(widget.text);
    _scrollController.addListener(() => _lastOffset = _scrollController.offset);
  }

  @override
  void didUpdateWidget(_BookBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _parsedLines = _parseChapter(widget.text);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _reading = context.read<ReadingProvider>();
      // Restore the saved reading position once the content has been laid out
      // (maxScrollExtent is only known after the first frame).
      final saved = _reading.bookScrollOffsetFor(widget.chapterId);
      if (saved > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final max = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(saved.clamp(0.0, max));
        });
      }
    }
  }

  @override
  void dispose() {
    // Persist the final position when leaving the chapter (navigation or pop).
    // Skip a chapter still at the top — no need to store a zero offset.
    if (_lastOffset > 0) {
      _reading.setBookScrollOffset(widget.chapterId, _lastOffset);
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Font size is driven by the A−/A+ controls in the app bar (see
    // ReadingProvider). Watching here rebuilds the body when it changes.
    final fontSize = context.watch<ReadingProvider>().bookFontSize;
    // The template carries theme + colour only; per-line font, size and leading
    // are chosen by script in _renderLines. letterSpacing stays 0 — any
    // positive value breaks Arabic cursive joins and the الله ligature.
    final template = context.textTheme.bodyLarge ?? const TextStyle();

    // SelectionArea makes the passages selectable/copyable — essential for a
    // study text. No pinch-zoom gesture here, so it never competes with the
    // PageView's horizontal swipe.
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _renderLines(
            template,
            fontSize,
            (
              verse: context.bookVerseColor,
              citation: context.bookCitationColor,
              hadith: context.bookHadithColor,
              // Brand gold, deliberately NOT one of the three scripture
              // colours: the masāʾil heading is structural, not a fourth
              // category of quoted text.
              masailHeading: context.brandColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet explaining the reader's colour coding. Swatches are sample
/// tokens rendered in the live theme colours, so the key always matches what
/// the reader currently shows in light or dark mode.
class _ColorKeySheet extends StatelessWidget {
  const _ColorKeySheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bookColorKey,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _ColorKeyRow(
              sample: '\u{FD3F}\u{2026}\u{FD3E}',
              color: context.bookVerseColor,
              label: l10n.bookLegendVerse,
            ),
            const SizedBox(height: 16),
            _ColorKeyRow(
              sample: '[\u{2026}]',
              color: context.bookCitationColor,
              label: l10n.bookLegendCitation,
            ),
            const SizedBox(height: 16),
            _ColorKeyRow(
              sample: '\u{00AB}\u{2026}\u{00BB}',
              color: context.bookHadithColor,
              label: l10n.bookLegendHadith,
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorKeyRow extends StatelessWidget {
  final String sample;
  final Color color;
  final String label;

  const _ColorKeyRow({
    required this.sample,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            sample,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              color: color,
              fontFamily: 'NotoNaskhArabic',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

/// Prev/next navigation bar. Reading order is right-to-left, so the chapter
/// that comes next sits to the left and the previous chapter to the right —
/// kept in LTR order regardless of the app's UI language. The callbacks drive
/// the [PageView]; a null callback disables (greys out) that direction at the
/// first/last chapter.
class _ChapterNavBar extends StatelessWidget {
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _ChapterNavBar({this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: onNext,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: onPrev,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
