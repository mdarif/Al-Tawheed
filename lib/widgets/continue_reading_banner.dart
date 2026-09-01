import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// A slim "Continue Reading" resume banner for the top of the Read tab's
/// chapter list — mirrors [ContinueListeningBanner]'s pattern for audio.
/// Renders `SizedBox.shrink()` when there is nothing to resume (fresh
/// install, or the saved chapter no longer exists in the current book — a
/// stale id left over from a removed chapter or an edition switch that
/// hasn't reloaded yet), so it never links to a broken state.
class ContinueReadingBanner extends StatelessWidget {
  const ContinueReadingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final reading = context.watch<ReadingProvider>();
    final book = context.watch<BookProvider>().book;

    final lastId = reading.lastChapterId;
    if (lastId == null || book == null) return const SizedBox.shrink();

    final index = book.chapters.indexWhere((c) => c.id == lastId);
    if (index == -1) return const SizedBox.shrink();
    final chapter = book.chapters[index];

    final series = context.read<SeriesProvider>().currentSeries;
    final isArabic = series.isRtl;
    final l10n = context.l10n;
    final fontFamily = series.bookFontFamily;

    final card = GestureDetector(
      onTap: () => context.push('/book/${chapter.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.groupedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.groupedBorder, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.semantic.brandSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: context.brandColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chapter.title,
                textAlign: isArabic ? TextAlign.right : null,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: fontFamily,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Explicit "start from top" (D2) — resumes the same chapter at
            // offset 0 instead of the saved scroll position. Separate tap
            // target from the card so it doesn't fight the resume tap.
            IconButton(
              tooltip: l10n.startFromTop,
              icon: Icon(
                Icons.replay_rounded,
                color: context.secondaryTextColor,
              ),
              onPressed: () =>
                  context.push('/book/${chapter.id}?startFromTop=true'),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            l10n.continueReading,
            textAlign: isArabic ? TextAlign.right : null,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          isArabic
              ? Directionality(textDirection: TextDirection.rtl, child: card)
              : card,
        ],
      ),
    );
  }
}
