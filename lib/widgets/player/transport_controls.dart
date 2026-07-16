import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

class PlayerTransportControls extends StatelessWidget {
  const PlayerTransportControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerNotifier, _Snapshot>(
      selector: (_, player) => _Snapshot(
        isPlaying: player.isPlaying,
        isLoading: player.isLoading,
        hasPrevious: player.hasPrevious,
        hasNext: player.hasNext,
      ),
      builder: (_, snapshot, __) {
        final enabledColor = context.primaryTextColor;
        final disabledColor = context.mutedIconColor;
        final player = context.read<PlayerNotifier>();
        final l10n = context.l10n;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 32,
              // tooltip doubles as the screen-reader label — these transport
              // controls were icon-only and announced as a bare "button".
              tooltip: l10n.playbackPrevious,
              icon: Icon(
                Icons.skip_previous_rounded,
                color: snapshot.hasPrevious ? enabledColor : disabledColor,
              ),
              onPressed: snapshot.hasPrevious ? player.playPrevious : null,
            ),
            IconButton(
              iconSize: 28,
              tooltip: l10n.playbackRewind,
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
                      tooltip: snapshot.isPlaying
                          ? l10n.playbackPause
                          : l10n.playbackPlay,
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
              tooltip: l10n.playbackForward,
              icon: Icon(Icons.forward_10_rounded, color: enabledColor),
              onPressed: player.skipForward,
            ),
            IconButton(
              iconSize: 32,
              tooltip: l10n.playbackNext,
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

class _Snapshot {
  final bool isPlaying;
  final bool isLoading;
  final bool hasPrevious;
  final bool hasNext;

  const _Snapshot({
    required this.isPlaying,
    required this.isLoading,
    required this.hasPrevious,
    required this.hasNext,
  });

  @override
  bool operator ==(Object other) =>
      other is _Snapshot &&
      other.isPlaying == isPlaying &&
      other.isLoading == isLoading &&
      other.hasPrevious == hasPrevious &&
      other.hasNext == hasNext;

  @override
  int get hashCode => Object.hash(isPlaying, isLoading, hasPrevious, hasNext);
}
