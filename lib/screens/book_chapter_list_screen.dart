import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

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
                    fontFamily: 'NotoNaskhArabic',
                  ),
                ),
              )
            : Text(l10n.tabBook),
      ),
      body: switch (provider.status) {
        BookStatus.idle || BookStatus.loading => Center(
            child: CircularProgressIndicator(color: context.brandColor),
          ),
        BookStatus.error => _ErrorBody(
            message: provider.error ?? l10n.bookCouldNotLoad,
            onRetry: () => provider.load(
              context.read<SeriesProvider>().currentSeries,
            ),
          ),
        BookStatus.loaded => _ChapterList(chapters: book!.chapters),
      },
    );
  }
}

class _ChapterList extends StatelessWidget {
  final List<BookChapter> chapters;

  const _ChapterList({required this.chapters});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return Column(
          children: [
            _ChapterTile(chapter: chapter),
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

  const _ChapterTile({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/book/${chapter.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _NumberBadge(number: chapter.number),
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
                    fontFamily: 'NotoNaskhArabic',
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

  const _NumberBadge({required this.number});

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
        number.toString().padLeft(2, '0'),
        style: context.textTheme.labelMedium?.copyWith(
          color: context.brandColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 52, color: context.mutedIconColor),
            const SizedBox(height: 20),
            Text(
              l10n.bookCouldNotLoad,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
