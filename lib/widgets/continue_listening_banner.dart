import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// A slim "Continue Listening" resume banner for the top of the Lectures tab —
/// the last-played lecture with its progress, resuming on tap. Renders
/// `SizedBox.shrink()` when there is nothing to resume (fresh install, or the
/// saved lecture is no longer in the catalog), so it never takes up space
/// needlessly. (Formerly the resume card on the retired Home tab.)
class ContinueListeningBanner extends StatelessWidget {
  const ContinueListeningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final catalog = context.watch<CatalogProvider>();

    final lastId = progress.lastLectureId;
    if (lastId == null || catalog.status != CatalogStatus.loaded) {
      return const SizedBox.shrink();
    }
    final lecture = catalog.catalog!.lectureById(lastId);
    if (lecture == null) return const SizedBox.shrink();

    final fraction = progress.getFraction(lastId, lecture.durationSeconds);
    final savedSeconds = progress.getPositionSeconds(lastId);
    final remaining = lecture.durationSeconds - savedSeconds;
    final series = context.read<SeriesProvider>().currentSeries;
    final isArabic = series.isRtl;
    final l10n = context.l10nForSeries(series);
    // Watch the language so the resolved title refreshes on a UI-language change.
    final lectureTitle = context
        .watch<LanguageProvider>()
        .resolveForSeries(lecture.title, series);

    final card = GestureDetector(
      onTap: () {
        context
            .read<PlayerNotifier>()
            .loadAndPlay(lecture, catalog.catalog!.lectures);
        context.push('/player');
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.groupedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.groupedBorder, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.semantic.brandSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.headphones_rounded,
                    color: context.brandColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          lectureTitle,
                          textAlign: isArabic ? TextAlign.right : null,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.listenedDuration(
                          DurationFormatter.fromSeconds(savedSeconds),
                          DurationFormatter.fromSeconds(remaining),
                        ),
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.brandColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: context.onBrandColor,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: context.progressTrackColor,
                color: context.brandColor,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.percentComplete((fraction * 100).round()),
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );

    // Self-padded so the caller can drop it in bare — when there's nothing to
    // resume it returns shrink() above and leaves no gap at the top of the list.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            l10n.continueListening,
            textAlign: isArabic ? TextAlign.right : null,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          // Mirror the whole card for the Arabic series (icon/play row flips,
          // the progress bar fills right-to-left).
          isArabic
              ? Directionality(textDirection: TextDirection.rtl, child: card)
              : card,
        ],
      ),
    );
  }
}
