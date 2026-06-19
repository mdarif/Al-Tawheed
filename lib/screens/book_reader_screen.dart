import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// The three theme-resolved highlight colours passed down to span building,
/// so the reader doesn't read [BuildContext] inside its text-layout helpers.
typedef _HighlightColors = ({Color verse, Color citation, Color hadith});

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

    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            chapter.title,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFamily: 'NotoNaskhArabic',
            ),
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
  const _BookBody({required this.text, required this.chapterId});

  @override
  State<_BookBody> createState() => _BookBodyState();
}

class _BookBodyState extends State<_BookBody> {
  bool _initialized = false;
  final _scrollController = ScrollController();
  double _lastOffset = 0;
  late ReadingProvider _reading;

  static final _verseRe = RegExp(r'\{[^}]+\}');
  static final _citationRe = RegExp(r'\[[^\[\]]+\]');
  static final _hadithRe = RegExp(r'\(\([^)]+(?:\)[^)]+)*\)\)');

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

  // 1 = verse, 2 = citation, 3 = hadith. Colours are resolved from the active
  // theme (see [_HighlightColors]) so each mode gets a shade tuned for contrast
  // against its reading background.
  List<TextSpan> _buildSpans(
    String line,
    TextStyle base,
    _HighlightColors colors,
  ) {
    // Eastern Arabic-Indic numerals for inline ayah numbers etc. Digit chars
    // map 1:1 so the regex match positions below stay valid.
    final text = arabicDigitsInString(line);

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

    final spans = <TextSpan>[];
    int last = 0;
    for (final (start, end, type) in intervals) {
      if (start > last) {
        spans.add(TextSpan(text: text.substring(last, start), style: base));
      }
      final color = type == 1
          ? colors.verse
          : type == 2
              ? colors.citation
              : colors.hadith;
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
      spans.add(
        TextSpan(
          text: segment,
          style: base.copyWith(color: color),
        ),
      );
      last = end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return spans;
  }

  List<Widget> _buildLines(TextStyle base, _HighlightColors colors) {
    final lines = widget.text.split('\n');
    final widgets = <Widget>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text.rich(
              TextSpan(children: _buildSpans(line, base, colors)),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() => _lastOffset = _scrollController.offset);
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
    final baseStyle = context.textTheme.bodyLarge?.copyWith(
          fontFamily: 'NotoNaskhArabic',
          fontSize: fontSize,
          height: 1.8,
          // letterSpacing must be 0/absent for Arabic — any positive value
          // inserts gaps between glyphs and breaks cursive joins and
          // ligatures (including the mandatory الله ligature).
        ) ??
        const TextStyle();

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
          children: _buildLines(
            baseStyle,
            (
              verse: context.bookVerseColor,
              citation: context.bookCitationColor,
              hadith: context.bookHadithColor,
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
