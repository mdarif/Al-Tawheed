import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/widgets/download_button.dart';
import 'package:myapp/widgets/settings/playback_speed_selector.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _StudyCompletionListener(
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Now Playing',
          style: context.textTheme.titleMedium?.copyWith(fontSize: 14),
        ),
        centerTitle: true,
        actions: [
          const _BookmarkButton(),
          if (context.select<FeatureFlagsProvider, bool>(
            (p) => p.features.downloads,
          ))
            const _PlayerDownloadButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 28),
              const _CoverArt(),
              const SizedBox(height: 32),
              const _TrackInfo(),
              const _StudyContextStrip(),
              const SizedBox(height: 32),
              const _SeekBar(),
              const SizedBox(height: 28),
              const _TransportControls(),
              const SizedBox(height: 24),
              const PlaybackSpeedSelectorCompact(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _StudyCompletionListener extends StatefulWidget {
  final Widget child;
  const _StudyCompletionListener({required this.child});

  @override
  State<_StudyCompletionListener> createState() =>
      _StudyCompletionListenerState();
}

class _StudyCompletionListenerState extends State<_StudyCompletionListener> {
  String? _handledChapterId;

  @override
  Widget build(BuildContext context) {
    final pending = context.select<PlayerNotifier, String?>(
      (p) => p.pendingStudyChapterCompleteId,
    );

    if (pending != null && pending != _handledChapterId) {
      _handledChapterId = pending;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = context.read<PlayerNotifier>();
        notifier.clearPendingStudyComplete();
        Navigator.of(context).pop();
        context.push('/study/complete?chapterId=$pending');
      });
    }

    return widget.child;
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.groupedBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(
              alpha: context.isDarkTheme ? 0.4 : 0.08,
            ),
            blurRadius: context.isDarkTheme ? 30 : 20,
            offset: Offset(0, context.isDarkTheme ? 12 : 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones_rounded,
              size: 72, color: context.brandColor),
          const SizedBox(height: 12),
          Text(
            'شرح كتاب التوحيد',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.brandColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo();

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerNotifier, String>(
      selector: (_, player) => player.current?.title.en ?? '',
      builder: (_, title, __) => Column(
        children: [
          Text(
            title,
            style: context.textTheme.headlineSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'Shaikh Abdullah Nasir Rahmani Hafizahullah',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyContextStrip extends StatelessWidget {
  const _StudyContextStrip();

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerNotifier, String?>(
      selector: (_, player) => player.studyContextLabel,
      builder: (_, label, __) {
        if (label == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.semantic.brandSubtle.withValues(
                alpha: context.isDarkTheme ? 0.35 : 0.55,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.brandColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerNotifier, _SeekSnapshot>(
      selector: (_, player) => _SeekSnapshot(
        progress: player.progress,
        positionSeconds: player.position.inSeconds,
        durationSeconds: player.duration.inSeconds,
      ),
      builder: (_, snapshot, __) {
        final sliderValue = _draggingValue ?? snapshot.progress;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: sliderValue.clamp(0.0, 1.0),
                onChangeStart: (v) => setState(() => _draggingValue = v),
                onChanged: (v) => setState(() => _draggingValue = v),
                onChangeEnd: (v) {
                  setState(() => _draggingValue = null);
                  context.read<PlayerNotifier>().seek(Duration(
                        milliseconds:
                            (v * snapshot.durationSeconds * 1000).round(),
                      ));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DurationFormatter.fromSeconds(snapshot.positionSeconds),
                    style: context.textTheme.bodySmall,
                  ),
                  Text(
                    DurationFormatter.fromSeconds(snapshot.durationSeconds),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeekSnapshot {
  final double progress;
  final int positionSeconds;
  final int durationSeconds;

  const _SeekSnapshot({
    required this.progress,
    required this.positionSeconds,
    required this.durationSeconds,
  });

  @override
  bool operator ==(Object other) =>
      other is _SeekSnapshot &&
      other.progress == progress &&
      other.positionSeconds == positionSeconds &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode => Object.hash(progress, positionSeconds, durationSeconds);
}

class _TransportControls extends StatelessWidget {
  const _TransportControls();

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerNotifier, _TransportSnapshot>(
      selector: (_, player) => _TransportSnapshot(
        isPlaying: player.isPlaying,
        isLoading: player.isLoading,
        hasPrevious: player.hasPrevious,
        hasNext: player.hasNext,
      ),
      builder: (_, snapshot, __) {
        final enabledColor = context.primaryTextColor;
        final disabledColor = context.mutedIconColor;
        final player = context.read<PlayerNotifier>();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 32,
              icon: Icon(
                Icons.skip_previous_rounded,
                color: snapshot.hasPrevious ? enabledColor : disabledColor,
              ),
              onPressed: snapshot.hasPrevious ? player.playPrevious : null,
            ),
            IconButton(
              iconSize: 28,
              icon: Icon(Icons.replay_10_rounded, color: enabledColor),
              onPressed: player.skipBackward,
            ),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: context.brandColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.brandColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: snapshot.isLoading
                  ? Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: context.onBrandColor,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : IconButton(
                      iconSize: 36,
                      icon: Icon(
                        snapshot.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: context.onBrandColor,
                      ),
                      onPressed: player.playPause,
                    ),
            ),
            IconButton(
              iconSize: 28,
              icon: Icon(Icons.forward_10_rounded, color: enabledColor),
              onPressed: player.skipForward,
            ),
            IconButton(
              iconSize: 32,
              icon: Icon(
                Icons.skip_next_rounded,
                color: snapshot.hasNext ? enabledColor : disabledColor,
              ),
              onPressed: snapshot.hasNext ? player.playNext : null,
            ),
          ],
        );
      },
    );
  }
}

class _TransportSnapshot {
  final bool isPlaying;
  final bool isLoading;
  final bool hasPrevious;
  final bool hasNext;

  const _TransportSnapshot({
    required this.isPlaying,
    required this.isLoading,
    required this.hasPrevious,
    required this.hasNext,
  });

  @override
  bool operator ==(Object other) =>
      other is _TransportSnapshot &&
      other.isPlaying == isPlaying &&
      other.isLoading == isLoading &&
      other.hasPrevious == hasPrevious &&
      other.hasNext == hasNext;

  @override
  int get hashCode => Object.hash(isPlaying, isLoading, hasPrevious, hasNext);
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton();

  @override
  Widget build(BuildContext context) {
    final lectureId = context.select<PlayerNotifier, String?>(
      (player) => player.current?.id,
    );
    if (lectureId == null) return const SizedBox.shrink();

    final isBookmarked = context.select<ProgressProvider, bool>(
      (p) => p.isBookmarked(lectureId),
    );

    return IconButton(
      tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
      icon: Icon(
        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
        color: isBookmarked ? context.brandColor : context.primaryTextColor,
      ),
      onPressed: () =>
          context.read<ProgressProvider>().toggleBookmark(lectureId),
    );
  }
}

class _PlayerDownloadButton extends StatelessWidget {
  const _PlayerDownloadButton();

  @override
  Widget build(BuildContext context) {
    final lecture = context.select<PlayerNotifier, Lecture?>(
      (p) => p.current,
    );
    if (lecture == null) return const SizedBox.shrink();
    return DownloadButton(lecture: lecture, size: 22);
  }
}
