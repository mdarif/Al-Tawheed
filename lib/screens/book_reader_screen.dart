import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            chapter.text,
            textAlign: TextAlign.right,
            style: context.textTheme.bodyLarge?.copyWith(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 20,
              height: 1.8,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _ChapterNavBar(prev: prev, next: next),
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
