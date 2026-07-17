import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/lecture_share.dart';
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
          onTap: blocked ? () => _showOfflineSnackBar(context) : onTap,
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
                  context.localizedTime(lecture.durationSeconds),
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
              // Lecture numbers count in the chrome's script, like every other
              // number in the UI — ٠١ under Arabic chrome, 01 under English.
              // (Not the Book's rule: its chapter badges follow the *edition*,
              // because they are set the way the print sets them.)
              Text(
                context.localizedDigits(
                  lecture.number.toString().padLeft(2, '0'),
                ),
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.brandColor,
                  fontFamily: context.numeralFontFamily,
                  height: 1.0,
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

/// Trailing area of the tile — adapts based on the downloads feature flag, with
/// a share button appended when the `shareButton` flag is on.
///
/// Downloads ON:  bookmark indicator (if saved) + download button
/// Downloads OFF: bookmark/play circle (current behaviour)
/// Share ON:      + a share button (in either case)
class _TileTrailing extends StatelessWidget {
  final Lecture lecture;
  const _TileTrailing({required this.lecture});

  @override
  Widget build(BuildContext context) {
    final downloadsEnabled = context.select<FeatureFlagsProvider, bool>(
      (p) => p.features.downloads,
    );
    final shareEnabled = context.select<FeatureFlagsProvider, bool>(
      (p) => p.features.shareLectureRow,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (downloadsEnabled) ...[
          Selector<ProgressProvider, bool>(
            selector: (_, p) => p.isBookmarked(lecture.id),
            builder: (_, saved, __) => saved
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(end: 2),
                    child: Icon(
                      Icons.bookmark_rounded,
                      size: 14,
                      color: context.brandColor,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          DownloadButton(lecture: lecture, size: 20),
        ] else
          Selector<ProgressProvider, bool>(
            selector: (_, p) => p.isBookmarked(lecture.id),
            builder: (_, isBookmarked, __) => Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.play_circle_outline_rounded,
              color: isBookmarked ? context.brandColor : context.mutedIconColor,
              size: 22,
            ),
          ),
        if (shareEnabled) _ShareTileButton(lecture: lecture),
      ],
    );
  }
}

/// Compact share affordance on a lecture row — shares a link to the lecture's
/// page on the website. Sized to match [DownloadButton] so the trailing row
/// stays tidy.
class _ShareTileButton extends StatelessWidget {
  final Lecture lecture;
  const _ShareTileButton({required this.lecture});

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: size + 8, minHeight: size + 8),
      tooltip: context.l10n.shareLecture,
      icon: Icon(Icons.share_rounded, size: size, color: context.mutedIconColor),
      onPressed: () {
        final series = context.read<SeriesProvider>().currentSeries;
        final title = context.read<LanguageProvider>().resolveForSeries(
              lecture.title,
              series,
            );
        final url = lectureWebUrl(
          lecture,
          series,
          websiteBase: context.read<AppConfigProvider>().config.links.website,
        );
        SharePlus.instance.share(
          ShareParams(text: lectureShareText(title: title, url: url)),
        );
      },
    );
  }
}
