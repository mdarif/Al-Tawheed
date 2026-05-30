import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/screens/player_screen.dart';
import 'package:myapp/theme/app_colors.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    if (!player.hasAudio) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PlayerScreen(),
        ),
      ),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
            top: BorderSide(color: AppColors.surfaceContainerDark, width: 0.5),
          ),
        ),
        child: Column(
          children: [
            // Thin progress bar at the very top of the mini player
            LinearProgressIndicator(
              value: player.progress,
              backgroundColor: AppColors.surfaceTintDark,
              color: AppColors.gold,
              minHeight: 2,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Headphones icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.headphones_rounded,
                        color: AppColors.gold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Lecture title
                    Expanded(
                      child: Text(
                        player.current?.title ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Play / Pause
                    IconButton(
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 28,
                      ),
                      onPressed: player.playPause,
                      padding: EdgeInsets.zero,
                    ),
                    // Close
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.onDarkSecondary,
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
