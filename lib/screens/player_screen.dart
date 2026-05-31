import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
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
    return Scaffold(
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
          _BookmarkButton(),
          if (context
              .watch<FeatureFlagsProvider>()
              .features
              .downloads)
            _PlayerDownloadButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 28),
              _CoverArt(),
              const SizedBox(height: 32),
              _TrackInfo(),
              const SizedBox(height: 32),
              _SeekBar(),
              const SizedBox(height: 28),
              _TransportControls(),
              const SizedBox(height: 24),
              const PlaybackSpeedSelectorCompact(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverArt extends StatelessWidget {
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
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    return Column(
      children: [
        Text(
          player.current?.title ?? '',
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
    );
  }
}

class _SeekBar extends StatefulWidget {
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    final sliderValue = _draggingValue ?? player.progress;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: sliderValue.clamp(0.0, 1.0),
            onChangeStart: (v) => setState(() => _draggingValue = v),
            onChanged: (v) => setState(() => _draggingValue = v),
            onChangeEnd: (v) {
              setState(() => _draggingValue = null);
              player.seek(Duration(
                milliseconds: (v * player.duration.inMilliseconds).round(),
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
                DurationFormatter.fromSeconds(player.position.inSeconds),
                style: context.textTheme.bodySmall,
              ),
              Text(
                DurationFormatter.fromSeconds(player.duration.inSeconds),
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    final enabledColor = context.primaryTextColor;
    final disabledColor = context.mutedIconColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 32,
          icon: Icon(
            Icons.skip_previous_rounded,
            color: player.hasPrevious ? enabledColor : disabledColor,
          ),
          onPressed: player.hasPrevious ? player.playPrevious : null,
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
          child: player.isLoading
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
                    player.isPlaying
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
            color: player.hasNext ? enabledColor : disabledColor,
          ),
          onPressed: player.hasNext ? player.playNext : null,
        ),
      ],
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    final lectureId = player.current?.id;
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

// ── Player download button ────────────────────────────────────────────────────

class _PlayerDownloadButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lecture = context.select<PlayerNotifier, dynamic>(
      (p) => p.current,
    );
    if (lecture == null) return const SizedBox.shrink();
    return DownloadButton(lecture: lecture, size: 22);
  }
}
