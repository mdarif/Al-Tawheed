import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    if (!player.hasAudio) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: context.groupedSurface,
          border: Border(
            top: BorderSide(color: context.groupedBorder, width: 0.5),
          ),
        ),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: player.progress,
              backgroundColor: context.progressTrackColor,
              color: context.brandColor,
              minHeight: 2,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.semantic.brandSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.headphones_rounded,
                        color: context.brandColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.current?.title ?? '',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.primaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 28,
                        color: context.primaryTextColor,
                      ),
                      onPressed: player.playPause,
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: context.mutedIconColor,
                      ),
                      onPressed: context.read<PlayerNotifier>().stop,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
