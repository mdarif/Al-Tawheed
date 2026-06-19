import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class BookReaderScreen extends StatelessWidget {
  final String chapterId;

  const BookReaderScreen({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context) {
    final book = context.watch<BookProvider>().book;
    if (book == null) {
      return Scaffold(appBar: AppBar());
    }

    final chapters = book.chapters;
    final index = chapters.indexWhere((c) => c.id == chapterId);
    final chapter = chapters[index];
    final prev = index > 0 ? chapters[index - 1] : null;
    final next = index < chapters.length - 1 ? chapters[index + 1] : null;

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
            icon: const Icon(Icons.share_rounded),
            tooltip: context.l10n.bookShareChapter,
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: '${chapter.title}\n\n${chapter.text}'),
            ),
          ),
        ],
      ),
      body: _BookBody(text: chapter.text, chapterId: chapter.id),
      bottomNavigationBar: _ChapterNavBar(prev: prev, next: next),
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
  double _fontSize = 20;
  double _baseFontSize = 20;
  bool _initialized = false;
  final _scrollController = ScrollController();
  double _lastOffset = 0;
  late ReadingProvider _reading;
  int _activePointers = 0;

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
      _fontSize = _reading.bookFontSize;
      _baseFontSize = _fontSize;
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
    final baseStyle = context.textTheme.bodyLarge?.copyWith(
          fontFamily: 'NotoNaskhArabic',
          fontSize: _fontSize,
          height: 1.8,
          // letterSpacing must be 0/absent for Arabic — any positive value
          // inserts gaps between glyphs and breaks cursive joins and
          // ligatures (including the mandatory الله ligature).
        ) ??
        const TextStyle();

    // Listener fires before gesture arena — use it to count active pointers
    // so we can disable scroll the instant a second finger touches, preventing
    // SingleChildScrollView from claiming the 2-finger gesture on Android.
    return Listener(
      onPointerDown: (_) => setState(() => _activePointers++),
      onPointerUp: (_) => setState(() => _activePointers--),
      onPointerCancel: (_) => setState(() => _activePointers--),
      child: GestureDetector(
        onScaleStart: (_) => _baseFontSize = _fontSize,
        onScaleUpdate: (details) {
          if (_activePointers < 2) return;
          setState(() {
            _fontSize = (_baseFontSize * details.scale).clamp(14.0, 32.0);
          });
        },
        onScaleEnd: (_) {
          if (_activePointers < 2) {
            context.read<ReadingProvider>().setBookFontSize(_fontSize);
          }
        },
        // SelectionArea makes the passages selectable/copyable — essential for
        // a study text. Selection (long-press/drag) and the 2-finger zoom
        // gesture don't conflict.
        child: SelectionArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            // Disable scroll while 2+ fingers are down so the scale gesture wins.
            physics: _activePointers >= 2
                ? const NeverScrollableScrollPhysics()
                : null,
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
          ),
        ),
      ),
    );
  }
}

/// Prev/next navigation bar. Reading order is right-to-left, so the chapter
/// that comes next sits to the left and the previous chapter to the right —
/// kept in LTR order regardless of the app's UI language.
class _ChapterNavBar extends StatelessWidget {
  final BookChapter? prev;
  final BookChapter? next;

  const _ChapterNavBar({this.prev, this.next});

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
                onPressed: next == null
                    ? null
                    : () => context.pushReplacement('/book/${next!.id}'),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: prev == null
                    ? null
                    : () => context.pushReplacement('/book/${prev!.id}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
