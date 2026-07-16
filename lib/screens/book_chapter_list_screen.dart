import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/app_overflow_menu.dart';
import 'package:myapp/widgets/catalog_error_body.dart';

class BookChapterListScreen extends StatefulWidget {
  const BookChapterListScreen({super.key});

  @override
  State<BookChapterListScreen> createState() => _BookChapterListScreenState();
}

class _BookChapterListScreenState extends State<BookChapterListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BookProvider>();
      if (provider.status == BookStatus.idle) {
        provider.load(context.read<SeriesProvider>().currentSeries);
      }
    });
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
      appBar: AppBar(
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
            chapters: book!.chapters,
            fontFamily: fontFamily,
            language: language,
          ),
      },
    );
  }
}

class _ChapterList extends StatelessWidget {
  final List<BookChapter> chapters;
  final String fontFamily;
  final String language;

  const _ChapterList({
    required this.chapters,
    required this.fontFamily,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
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

