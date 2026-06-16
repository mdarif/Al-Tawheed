import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

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
      body: _BookBody(text: chapter.text),
      bottomNavigationBar: _ChapterNavBar(prev: prev, next: next),
    );
  }
}

class _BookBody extends StatefulWidget {
  final String text;
  const _BookBody({required this.text});

  @override
  State<_BookBody> createState() => _BookBodyState();
}

class _BookBodyState extends State<_BookBody> {
  double _fontSize = 20;
  double _baseFontSize = 20;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _fontSize = context.read<ReadingProvider>().bookFontSize;
      _baseFontSize = _fontSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (_) => _baseFontSize = _fontSize,
      onScaleUpdate: (details) {
        setState(() {
          _fontSize = (_baseFontSize * details.scale).clamp(14.0, 32.0);
        });
      },
      onScaleEnd: (_) => context.read<ReadingProvider>().setBookFontSize(_fontSize),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            widget.text,
            textAlign: TextAlign.right,
            style: context.textTheme.bodyLarge?.copyWith(
              fontFamily: 'NotoNaskhArabic',
              fontSize: _fontSize,
              height: 1.8,
              letterSpacing: 0.3,
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
