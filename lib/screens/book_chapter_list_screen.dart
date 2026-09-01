import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/reader_scroll_physics.dart';
import 'package:myapp/utils/scroll_immersion_detector.dart';
import 'package:myapp/widgets/app_overflow_menu.dart';
import 'package:myapp/widgets/catalog_error_body.dart';

const _kChromeAnim = Duration(milliseconds: 220);

class BookChapterListScreen extends StatefulWidget {
  const BookChapterListScreen({super.key});

  @override
  State<BookChapterListScreen> createState() => _BookChapterListScreenState();
}

class _BookChapterListScreenState extends State<BookChapterListScreen> {
  final _scrollController = ScrollController();
  final _immersion = ScrollImmersionDetector();
  bool _chromeVisible = true;
  double _lastOffset = 0;
  ShellChromeProvider? _shellChrome;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BookProvider>();
      if (provider.status == BookStatus.idle) {
        provider.load(context.read<SeriesProvider>().currentSeries);
      }
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastOffset;
    if (offset <= 8 || delta < -6) {
      _setChromeVisible(true);
    } else if (delta > 6) {
      _setChromeVisible(false);
    }
    _lastOffset = offset;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final hidden = _immersion.update(notification);
    if (hidden != null) _setChromeVisible(!hidden);
    return false;
  }

  void _setChromeVisible(bool visible) {
    if (_chromeVisible != visible) setState(() => _chromeVisible = visible);
    _shellChrome?.setVisible(visible);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shellChrome = context.read<ShellChromeProvider>();
    if (_shellChrome == shellChrome) return;
    _shellChrome?.show();
    _shellChrome = shellChrome..show();
  }

  @override
  void dispose() {
    _shellChrome?.show();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookProvider>();
    final book = provider.book;
    final l10n = context.l10n;
    final series = context.watch<SeriesProvider>().currentSeries;
    final fontFamily = series.bookFontFamily;
    final language = series.language;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _SlidingAppBar(
        visible: _chromeVisible,
        child: AppBar(
          title: book != null
              ? Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    book.title,
                    textAlign: TextAlign.right,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: fontFamily,
                    ),
                  ),
                )
              : Text(l10n.tabBook),
          actions: const [AppOverflowMenu()],
        ),
      ),
      body: switch (provider.status) {
        BookStatus.idle || BookStatus.loading => Center(
            child: CircularProgressIndicator(color: context.brandColor),
          ),
        BookStatus.error => CatalogErrorBody(
            icon: Icons.menu_book_outlined,
            title: l10n.bookCouldNotLoad,
            message: provider.error ?? l10n.bookCouldNotLoad,
            onRetry: () => provider.load(
              context.read<SeriesProvider>().currentSeries,
            ),
          ),
        BookStatus.loaded => _ChapterList(
            controller: _scrollController,
            onScrollNotification: _onScrollNotification,
            chapters: book!.chapters,
            fontFamily: fontFamily,
            language: language,
          ),
      },
    );
  }
}

/// Book content only, no `Scaffold`/`AppBar` — embedded inside `ReadScreen`'s
/// single shared header. Unlike [BookChapterListScreen], scrolling here does
/// not hide a local app bar (there is no local one); the bottom nav still
/// hides on scroll via [ShellChromeProvider], same as every other branch.
class BookChapterListBody extends StatefulWidget {
  const BookChapterListBody({super.key});

  @override
  State<BookChapterListBody> createState() => _BookChapterListBodyState();
}

class _BookChapterListBodyState extends State<BookChapterListBody> {
  final _scrollController = ScrollController();
  double _lastOffset = 0;
  ShellChromeProvider? _shellChrome;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BookProvider>();
      if (provider.status == BookStatus.idle) {
        provider.load(context.read<SeriesProvider>().currentSeries);
      }
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastOffset;
    if (offset <= 8 || delta < -6) {
      _shellChrome?.setVisible(true);
    } else if (delta > 6) {
      _shellChrome?.setVisible(false);
    }
    _lastOffset = offset;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shellChrome = context.read<ShellChromeProvider>();
    if (_shellChrome == shellChrome) return;
    _shellChrome?.show();
    _shellChrome = shellChrome..show();
  }

  @override
  void dispose() {
    _shellChrome?.show();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookProvider>();
    final book = provider.book;
    final l10n = context.l10n;
    final series = context.watch<SeriesProvider>().currentSeries;
    final fontFamily = series.bookFontFamily;
    final language = series.language;

    return switch (provider.status) {
      BookStatus.idle || BookStatus.loading => Center(
          child: CircularProgressIndicator(color: context.brandColor),
        ),
      BookStatus.error => CatalogErrorBody(
          icon: Icons.menu_book_outlined,
          title: l10n.bookCouldNotLoad,
          message: provider.error ?? l10n.bookCouldNotLoad,
          onRetry: () => provider.load(
            context.read<SeriesProvider>().currentSeries,
          ),
        ),
      BookStatus.loaded => ListView.builder(
          controller: _scrollController,
          physics: const ReaderClampEdgesPhysics(),
          itemCount: book!.chapters.length,
          itemBuilder: (context, index) {
            final chapter = book.chapters[index];
            return Column(
              children: [
                _ChapterTile(
                  chapter: chapter,
                  displayNumber: index + 1,
                  fontFamily: fontFamily,
                  language: language,
                ),
                Divider(
                  height: 1,
                  indent: 70,
                  endIndent: 16,
                  color: context.dividerColor,
                ),
              ],
            );
          },
        ),
    };
  }
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

class _ChapterList extends StatelessWidget {
  final ScrollController controller;
  final ValueChanged<ScrollNotification> onScrollNotification;
  final List<BookChapter> chapters;
  final String fontFamily;
  final String language;

  const _ChapterList({
    required this.controller,
    required this.onScrollNotification,
    required this.chapters,
    required this.fontFamily,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        onScrollNotification(notification);
        return false;
      },
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView.builder(
          controller: controller,
          physics: const ReaderClampEdgesPhysics(),
          padding: EdgeInsets.only(top: topInset),
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            return Column(
              children: [
                _ChapterTile(
                  chapter: chapter,
                  // 1-based position, so the list reads ۱, ۲, ۳… not ۰, ۱, ۲…
                  displayNumber: index + 1,
                  fontFamily: fontFamily,
                  language: language,
                ),
                Divider(
                  height: 1,
                  indent: 70,
                  endIndent: 16,
                  color: context.dividerColor,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final BookChapter chapter;
  final int displayNumber;
  final String fontFamily;
  final String language;

  const _ChapterTile({
    required this.chapter,
    required this.displayNumber,
    required this.fontFamily,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/book/${chapter.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _NumberBadge(
              number: displayNumber,
              language: language,
              fontFamily: fontFamily,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  chapter.title,
                  textAlign: TextAlign.right,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  final String language;

  /// The series' book font. Urdu and Persian share the numeral codepoints
  /// (U+06F0–06F9) but draw 4/5/6/7 differently, so the digits must render in
  /// the Urdu face (Noto Nastaliq Urdu) to get the shapes an Urdu reader
  /// expects — the default UI font falls back to a Persian-style face.
  final String fontFamily;

  const _NumberBadge({
    required this.number,
    required this.language,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        localizedDigitsInString(number.toString().padLeft(2, '0'), language),
        style: context.textTheme.labelMedium?.copyWith(
          color: context.brandColor,
          fontFamily: fontFamily,
          // Nastaliq numerals sit taller than the UI font's; a neutral height
          // keeps them optically centred in the 40×40 badge.
          height: 1.0,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
