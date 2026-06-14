import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/download_button.dart';

class LectureTile extends StatelessWidget {
  final Lecture lecture;
  final VoidCallback? onTap;

  const LectureTile({super.key, required this.lecture, this.onTap});

  @override
  Widget build(BuildContext context) {
    final downloadsEnabled = context.select<FeatureFlagsProvider, bool>(
      (p) => p.features.downloads,
    );

    // Offline guard only active when downloads feature is on
    if (downloadsEnabled) {
      final isOffline = context.select<ConnectivityProvider, bool>(
        (c) => c.isOffline,
      );
      final isDownloaded = context.select<DownloadsProvider, bool>(
        (d) => d.isDownloaded(lecture.id),
      );
      final blocked = isOffline && !isDownloaded;

      return Opacity(
        opacity: blocked ? 0.45 : 1.0,
        child: InkWell(
          onTap: blocked
              ? () => _showOfflineSnackBar(context)
              : onTap,
          child: _TileContent(lecture: lecture),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: _TileContent(lecture: lecture),
    );
  }

  void _showOfflineSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.offlineNotDownloaded),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _TileContent extends StatelessWidget {
  final Lecture lecture;
  const _TileContent({required this.lecture});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _ProgressBadge(lecture: lecture),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lecture.titleArabic != null) ...[
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      lecture.titleArabic!,
                      textAlign: TextAlign.right,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                _buildTitle(context),
                const SizedBox(height: 3),
                Text(
                  DurationFormatter.fromSeconds(lecture.durationSeconds),
                  style: context.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _TileTrailing(lecture: lecture),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final series = context.read<SeriesProvider>().currentSeries;
    final title = context.read<LanguageProvider>().resolveForSeries(
          lecture.title,
          series,
        );
    final style = context.textTheme.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

    if (series.isRtl) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Text(title, textAlign: TextAlign.right, style: style),
      );
    }
    return Text(title, style: style);
  }
}

class _ProgressBadge extends StatelessWidget {
  final Lecture lecture;
  const _ProgressBadge({required this.lecture});

  @override
  Widget build(BuildContext context) {
    return Selector<ProgressProvider, double>(
      selector: (_, p) => p.getFraction(lecture.id, lecture.durationSeconds),
      builder: (_, fraction, __) {
        final hasProgress = fraction > 0.01;
        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.elevatedSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              if (hasProgress)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.transparent,
                    color: fraction >= 0.99
                        ? context.brandColor
                        : context.brandColor.withValues(alpha: 0.6),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              Text(
                lecture.number.toString().padLeft(2, '0'),
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.brandColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Trailing area of the tile — adapts based on the downloads feature flag.
///
/// Downloads ON:  bookmark indicator (if saved) + download button
/// Downloads OFF: bookmark/play circle (current behaviour)
class _TileTrailing extends StatelessWidget {
  final Lecture lecture;
  const _TileTrailing({required this.lecture});

  @override
  Widget build(BuildContext context) {
    final downloadsEnabled = context.select<FeatureFlagsProvider, bool>(
      (p) => p.features.downloads,
    );

    if (downloadsEnabled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Selector<ProgressProvider, bool>(
            selector: (_, p) => p.isBookmarked(lecture.id),
            builder: (_, saved, __) => saved
                ? Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.bookmark_rounded,
                      size: 14,
                      color: context.brandColor,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          DownloadButton(lecture: lecture, size: 20),
        ],
      );
    }

    return Selector<ProgressProvider, bool>(
      selector: (_, p) => p.isBookmarked(lecture.id),
      builder: (_, isBookmarked, __) => Icon(
        isBookmarked
            ? Icons.bookmark_rounded
            : Icons.play_circle_outline_rounded,
        color:
            isBookmarked ? context.brandColor : context.mutedIconColor,
        size: 22,
      ),
    );
  }
}
