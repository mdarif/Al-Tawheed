import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/widgets/selection_chip.dart';

class PlaybackSpeedSelector extends StatelessWidget {
  const PlaybackSpeedSelector({super.key});

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: _speeds.map((speed) {
        final selected = (player.speed - speed).abs() < 0.01;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SelectionChip(
            label: '${speed}x',
            selected: selected,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onTap: () {
              HapticFeedback.selectionClick();
              player.setSpeed(speed);
            },
          ),
        );
      }).toList(),
    );
  }
}

/// Compact variant for the player screen.
class PlaybackSpeedSelectorCompact extends StatelessWidget {
  const PlaybackSpeedSelectorCompact({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: PlaybackSpeedSelector._speeds.map((speed) {
        final selected = (player.speed - speed).abs() < 0.01;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SelectionChip(
            label: '${speed}x',
            selected: selected,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            onTap: () {
              HapticFeedback.selectionClick();
              player.setSpeed(speed);
            },
          ),
        );
      }).toList(),
    );
  }
}
