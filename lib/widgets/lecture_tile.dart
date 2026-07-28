import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/audio/player_notifier.dart';
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

class LectureTile extends StatefulWidget {
  final Lecture lecture;
  final VoidCallback? onTap;

  const LectureTile({super.key, required this.lecture, this.onTap});

  @override
  State<LectureTile> createState() => _LectureTileState();
}

class _LectureTileState extends State<LectureTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isCurrent = context.select<PlayerNotifier, bool>(
      (p) => p.current?.id == widget.lecture.id,
    );
    final isPlaying = context.select<PlayerNotifier, bool>((p) => p.isPlaying);
    final downloadsEnabled = context.select<FeatureFlagsProvider, bool>(
      (p) => p.features.downloads,
    );

    // Offline guard only active when downloads feature is on
    if (downloadsEnabled) {
      final isOffline = context.select<ConnectivityProvider, bool>(
        (c) => c.isOffline,
      );
      final isDownloaded = context.select<DownloadsProvider, bool>(
        (d) => d.isDownloaded(widget.lecture.id),
      );
      final blocked = isOffline && !isDownloaded;

      return _PressableTileShell(
        pressed: _pressed,
        highlighted: isCurrent,
        onHighlightChanged: (value) => setState(() => _pressed = value),
        onTap: blocked ? () => _showOfflineSnackBar(context) : widget.onTap,
        child: _TileContent(
          lecture: widget.lecture,
          isCurrent: isCurrent,
          isPlaying: isPlaying,
          isOfflineUnavailable: blocked,
        ),
      );
    }

    return _PressableTileShell(
      pressed: _pressed,
      highlighted: isCurrent,
      onHighlightChanged: (value) => setState(() => _pressed = value),
      onTap: widget.onTap,
      child: _TileContent(
        lecture: widget.lecture,
        isCurrent: isCurrent,
        isPlaying: isPlaying,
        isOfflineUnavailable: false,
      ),
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

class _PressableTileShell extends StatelessWidget {
  final bool pressed;
  final bool highlighted;
  final ValueChanged<bool> onHighlightChanged;
  final VoidCallback? onTap;
  final Widget child;

  const _PressableTileShell({
    required this.pressed,
    required this.highlighted,
    required this.onHighlightChanged,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      color: pressed
          ? context.brandColor.withValues(alpha: 0.06)
          : highlighted
              ? context.brandColor.withValues(alpha: 0.07)
              : Colors.transparent,
      child: InkWell(
        onHighlightChanged: onHighlightChanged,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _TileContent extends StatelessWidget {
  final Lecture lecture;
  final bool isCurrent;
  final bool isPlaying;
  final bool isOfflineUnavailable;

  const _TileContent({
    required this.lecture,
    required this.isCurrent,
    required this.isPlaying,
    required this.isOfflineUnavailable,
  });

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
                if (isOfflineUnavailable) ...[
                  const SizedBox(height: 4),
                  _OfflineCue(),
                ],
                if (isCurrent) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NowPlayingBars(
                        color: context.brandColor,
                        playing: isPlaying,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.nowPlaying,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.brandColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
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

class NowPlayingBars extends StatefulWidget {
  final Color color;
  final bool playing;

  const NowPlayingBars({
    super.key,
    required this.color,
    required this.playing,
  });

  @override
  State<NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends State<NowPlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..value = 0.35;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant NowPlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 15,
      height: 13,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _NowPlayingBar(
              color: widget.color,
              height: _barHeight(0.00),
            ),
            const SizedBox(width: 2),
            _NowPlayingBar(
              color: widget.color,
              height: _barHeight(0.36),
            ),
            const SizedBox(width: 2),
            _NowPlayingBar(
              color: widget.color,
              height: _barHeight(0.72),
            ),
          ],
        ),
      ),
    );
  }

  double _barHeight(double phase) {
    final value = (_controller.value + phase) % 1.0;
    final pulse = value < 0.5 ? value * 2 : (1 - value) * 2;
    return 4 + (pulse * 9);
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.playing && !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
      return;
    }

    if (_controller.isAnimating) _controller.stop();
    if (_controller.value != 0.35) _controller.value = 0.35;
  }
}

class _NowPlayingBar extends StatelessWidget {
  final Color color;
  final double height;

  const _NowPlayingBar({required this.color, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _OfflineCue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, size: 13, color: context.mutedIconColor),
        const SizedBox(width: 4),
        Text(
          context.l10n.offlineBadge,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.secondaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
        final isComplete = fraction >= 0.99;
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
                  color: isComplete
                      ? context.brandColor.withValues(alpha: 0.14)
                      : context.elevatedSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              if (hasProgress && !isComplete)
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
              if (isComplete)
                Icon(Icons.check_rounded, size: 18, color: context.brandColor)
              else
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
      constraints:
          const BoxConstraints(minWidth: size + 8, minHeight: size + 8),
      tooltip: context.l10n.shareLecture,
      icon:
          Icon(Icons.share_rounded, size: size, color: context.mutedIconColor),
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
