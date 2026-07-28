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
import 'package:myapp/utils/reader_scroll_physics.dart';
import 'package:myapp/utils/scroll_immersion_detector.dart';
import 'package:myapp/widgets/book/report_mistake.dart';
import 'package:myapp/widgets/book/scroll_to_top_button.dart';

/// The three theme-resolved highlight colours passed down to span building,
/// so the reader doesn't read [BuildContext] inside its text-layout helpers.
typedef _HighlightColors = ({
  Color verse,
  Color citation,
  Color hadith,
  Color masailHeading,
});

/// The reader's secondary actions, gathered behind the app-bar ⋮.
enum _ReaderAction { colorKey, share, report }

const _kChromeAnim = Duration(milliseconds: 220);
const _kReaderBottomTextGap = 28.0;

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
  bool _chromeVisible = true;

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

  void _setChromeVisible(bool visible) {
    if (_chromeVisible == visible) return;
    setState(() => _chromeVisible = visible);
  }

  static const _minFontSize = 14.0;
  static const _maxFontSize = 32.0;

  // Pinch-to-zoom, done with a passive [Listener] rather than a scale gesture
  // recognizer — the same approach as the Quran app. Tracking raw pointers
  // keeps it out of the gesture arena entirely, so single-finger scroll, the
  // page swipe, and text selection are never stolen. A pinch just locks the
  // pager and resizes the text; there is no on-screen control.
  final Map<int, Offset> _pointers = {};
  double? _pinchBaseDistance;
  double _fontAtPinchStart = 0;
  bool _pageLocked = false;

  double _pointerSpread() {
    final pts = _pointers.values.toList(growable: false);
    return (pts[0] - pts[1]).distance;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _pinchBaseDistance = _pointerSpread();
      _fontAtPinchStart = context.read<ReadingProvider>().bookFontSize;
      if (!_pageLocked) setState(() => _pageLocked = true);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final base = _pinchBaseDistance;
    if (_pointers.length == 2 && base != null && base > 0) {
      // Snap to whole points: pinch feeds a continuous value on every move, and
      // reshaping a whole chapter on each fractional change stutters badly. One
      // reshape per 1pt crossing is imperceptible. (Lesson from the Quran app.)
      final next = (_fontAtPinchStart * (_pointerSpread() / base))
          .clamp(_minFontSize, _maxFontSize)
          .roundToDouble();
      context.read<ReadingProvider>().setBookFontSizeLive(next);
    }
  }

  void _onPointerEnd(PointerEvent e) {
    final wasPinching = _pointers.length == 2;
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchBaseDistance = null;
    // A finger lifted out of a pinch — persist the size the live updates left.
    if (wasPinching) {
      context.read<ReadingProvider>().commitBookFontSize();
    }
    if (_pointers.isEmpty && _pageLocked) {
      setState(() => _pageLocked = false);
    }
  }

  PopupMenuItem<_ReaderAction> _readerMenuItem(
    _ReaderAction action,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<_ReaderAction>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          // Flexible so a long label (or a long translation) ellipsizes within
          // the menu instead of overflowing the row.
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
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
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: _SlidingAppBar(
        visible: _chromeVisible,
        child: AppBar(
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
                Text(
                  '${localizedDigitsInString('${_currentIndex + 1}', language)}'
                  ' / '
                  '${localizedDigitsInString('${_chapters.length}', language)}',
                  textAlign: TextAlign.right,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.secondaryTextColor.withValues(alpha: 0.72),
                    fontFamily: fontFamily,
                    fontSize: 10,
                    height: 0.95,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Just the ⋮ — text size is set by pinch-to-zoom (no on-screen
            // control), so the chapter title gets the width the A−/A+ buttons
            // used to take.
            PopupMenuButton<_ReaderAction>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) {
                switch (action) {
                  case _ReaderAction.colorKey:
                    _showColorKey(context);
                  case _ReaderAction.share:
                    SharePlus.instance.share(
                      ShareParams(
                        text: '${chapter.title}\n\n${chapter.text}',
                      ),
                    );
                  case _ReaderAction.report:
                    reportBookMistake(
                      context,
                      chapterNumber: chapter.number,
                      chapterTitle: chapter.title,
                    );
                }
              },
              itemBuilder: (context) => [
                _readerMenuItem(
                  _ReaderAction.colorKey,
                  Icons.palette_outlined,
                  context.l10n.bookColorKey,
                ),
                _readerMenuItem(
                  _ReaderAction.share,
                  Icons.share_rounded,
                  context.l10n.bookShareChapter,
                ),
                // Only when a report has somewhere to go.
                if (hasBookContact(context))
                  _readerMenuItem(
                    _ReaderAction.report,
                    Icons.flag_outlined,
                    context.l10n.bookReportIssue,
                  ),
              ],
            ),
          ],
        ),
      ),
      // The Listener passively watches pointers for the pinch-to-zoom (see the
      // _onPointer* handlers); it never enters the gesture arena, so it can't
      // steal scroll/swipe/selection.
      //
      // SelectionArea wraps the pager (ancestor) so passages stay
      // selectable/copyable via long-press, while the PageView — being the
      // deeper widget — wins horizontal swipes in the gesture arena. That lets
      // both coexist: long-press selects, a horizontal drag turns the page.
      //
      // Horizontal pager — swipe to turn the page like a printed book.
      // reverse:true matches RTL reading order: a left-to-right swipe advances
      // to the next chapter (which sits to the left), right-to-left goes back.
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: SelectionArea(
          child: PageView.builder(
            controller: controller,
            reverse: true,
            // Freeze paging while two fingers are down, so a pinch resizes the
            // text instead of turning the page.
            physics: _pageLocked ? const NeverScrollableScrollPhysics() : null,
            itemCount: _chapters.length,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              _setChromeVisible(true);
            },
            itemBuilder: (context, i) => _BookBody(
              key: ValueKey(_chapters[i].id),
              text: _chapters[i].text,
              chapterId: _chapters[i].id,
              fontFamily: fontFamily,
              language: language,
              onChromeVisibilityChanged: _setChromeVisible,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookBody extends StatefulWidget {
  final String text;
  final String chapterId;
  final String fontFamily;
  final String language;
  final ValueChanged<bool> onChromeVisibilityChanged;
  const _BookBody({
    super.key,
    required this.text,
    required this.chapterId,
    required this.fontFamily,
    required this.language,
    required this.onChromeVisibilityChanged,
  });

  @override
  State<_BookBody> createState() => _BookBodyState();
}

class _SlidingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool visible;
  final PreferredSizeWidget child;

  const _SlidingAppBar({required this.visible, required this.child});

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1),
      duration: _kChromeAnim,
      curve: Curves.easeOut,
      child: child,
    );
  }
}

class _BookBodyState extends State<_BookBody> {
  bool _initialized = false;
  final _scrollController = ScrollController();
  final _immersion = ScrollImmersionDetector();
  double _lastOffset = 0;

  // The "back to top" button shows once you're a screenful or so down. A little
  // hysteresis (show past 400, hide before 240) stops it flickering while you
  // scroll around the threshold.
  bool _showScrollTop = false;
  static const _showTopAbove = 400.0;
  static const _hideTopBelow = 240.0;

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
      final height = runs.any((r) => _urduLetters.hasMatch(r.$1))
          ? _urduHeight
          : _arabicHeight;

      // The masāʾil heading closes the matn and opens the author's summary
      // points — mark the seam with a rule and extra space above it.
      if (runs.length == 1 && runs.first.$2 == 4) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            child: Divider(
              height: 1,
              thickness: 1,
              color: colors.masailHeading.withValues(alpha: 0.35),
            ),
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
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastOffset;
    if (offset <= 8 || delta < -6) {
      widget.onChromeVisibilityChanged(true);
    } else if (delta > 6) {
      widget.onChromeVisibilityChanged(false);
    }
    _lastOffset = offset;
    final show = _showScrollTop
        ? _lastOffset > _hideTopBelow
        : _lastOffset > _showTopAbove;
    if (show != _showScrollTop) setState(() => _showScrollTop = show);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final hidden = _immersion.update(notification);
    if (hidden != null) widget.onChromeVisibilityChanged(!hidden);
    return false;
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Font size is driven by the A−/A+ controls in the app bar (see
    // ReadingProvider). Watching here rebuilds the body when it changes.
    // Driven by pinch-to-zoom (see the reader's _onPointer* handlers). Watching
    // here rebuilds the body live as the size changes.
    final fontSize = context.watch<ReadingProvider>().bookFontSize;
    // The template carries theme + colour only; per-line font, size and leading
    // are chosen by script in _renderLines. letterSpacing stays 0 — any
    // positive value breaks Arabic cursive joins and the الله ligature.
    final template = context.textTheme.bodyLarge ?? const TextStyle();
    final media = MediaQuery.of(context);
    final contentPadding = EdgeInsets.fromLTRB(
      20,
      media.padding.top + 8,
      20,
      media.padding.bottom + _kReaderBottomTextGap,
    );

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const ReaderClampEdgesPhysics(),
            padding: contentPadding,
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
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: ScrollToTopButton(
            visible: _showScrollTop,
            onPressed: _scrollToTop,
          ),
        ),
      ],
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
          // RTL regardless of the chrome locale: these are samples of Arabic
          // typography, and the ornate parentheses are bidi-neutral, so in an
          // LTR sheet U+FD3F lands on the left — where its glyph reads as a
          // *closing* brace and the key showed ﴾…﴿ mirrored. Matching the
          // reader body's direction is what makes the sample match the page.
          child: Directionality(
            textDirection: TextDirection.rtl,
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
