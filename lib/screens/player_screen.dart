import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/utils/duration_formatter.dart';

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
        title: const Text(
          'Now Playing',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        actions: [
          _BookmarkButton(),
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
              _SpeedControl(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cover art ────────────────────────────────────────────────────────────────

class _CoverArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones_rounded, size: 72, color: AppColors.gold),
          const SizedBox(height: 12),
          Text(
            'شرح كتاب التوحيد',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Track info ───────────────────────────────────────────────────────────────

class _TrackInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    return Column(
      children: [
        Text(
          player.current?.title ?? '',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          'Shaikh Abdullah Nasir Rahmani Hafizahullah',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onDarkSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Seek bar ─────────────────────────────────────────────────────────────────

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
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onDarkSecondary,
                ),
              ),
              Text(
                DurationFormatter.fromSeconds(player.duration.inSeconds),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onDarkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Transport controls ────────────────────────────────────────────────────────

class _TransportControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous lecture
        IconButton(
          iconSize: 32,
          icon: Icon(
            Icons.skip_previous_rounded,
            color: player.hasPrevious
                ? AppColors.onDark
                : AppColors.onDarkSecondary,
          ),
          onPressed: player.hasPrevious ? player.playPrevious : null,
        ),
        // Skip back 10s
        IconButton(
          iconSize: 28,
          icon: const Icon(Icons.replay_10_rounded),
          onPressed: player.skipBackward,
        ),
        // Play / Pause
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
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
                      color: AppColors.onLight,
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
                    color: Colors.black,
                  ),
                  onPressed: player.playPause,
                ),
        ),
        // Skip forward 10s
        IconButton(
          iconSize: 28,
          icon: const Icon(Icons.forward_10_rounded),
          onPressed: player.skipForward,
        ),
        // Next lecture
        IconButton(
          iconSize: 32,
          icon: Icon(
            Icons.skip_next_rounded,
            color:
                player.hasNext ? AppColors.onDark : AppColors.onDarkSecondary,
          ),
          onPressed: player.hasNext ? player.playNext : null,
        ),
      ],
    );
  }
}

// ── Bookmark button ────────────────────────────────────────────────────────────

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
        color: isBookmarked ? AppColors.gold : AppColors.onDark,
      ),
      onPressed: () =>
          context.read<ProgressProvider>().toggleBookmark(lectureId),
    );
  }
}

// ── Speed control ─────────────────────────────────────────────────────────────

class _SpeedControl extends StatelessWidget {
  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _speeds.map((s) {
        final selected = (player.speed - s).abs() < 0.01;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => player.setSpeed(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    selected ? AppColors.gold : AppColors.surfaceContainerDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${s}x',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.black : AppColors.onDarkSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
