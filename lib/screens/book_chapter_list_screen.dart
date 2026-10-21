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
import 'package:myapp/widgets/catalog_error_body.dart';
import 'package:myapp/widgets/continue_reading_banner.dart';

/// The Book tab: the continue-reading banner and the chapter list. Embedded
/// inside `ReadScreen`, which owns the header; it has no `Scaffold`/`AppBar`
/// of its own. Scrolling hides the bottom nav via [ShellChromeProvider], same
/// as every other branch.
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
    final chapters = provider.book?.chapters ?? const [];
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
      BookStatus.loaded => CustomScrollView(
          controller: _scrollController,
          physics: const ReaderClampEdgesPhysics(),
          slivers: [
            // Resume-where-you-left-off, atop the list — self-hides when
            // there's nothing to resume, mirroring ContinueListeningBanner
            // on Lectures.
            const SliverToBoxAdapter(child: ContinueReadingBanner()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = chapters[index];
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
                childCount: chapters.length,
              ),
            ),
          ],
        ),
    };
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
