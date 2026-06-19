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
      children: [
        for (var i = 0; i < _speeds.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < _speeds.length - 1 ? 6 : 0),
              child: _SpeedChip(
                speed: _speeds[i],
                selected: (player.speed - _speeds[i]).abs() < 0.01,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                onSelect: () => player.setSpeed(_speeds[i]),
              ),
            ),
          ),
      ],
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
      children: [
        for (var i = 0; i < PlaybackSpeedSelector._speeds.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i < PlaybackSpeedSelector._speeds.length - 1 ? 4 : 0,
              ),
              child: _SpeedChip(
                speed: PlaybackSpeedSelector._speeds[i],
                selected:
                    (player.speed - PlaybackSpeedSelector._speeds[i]).abs() <
                        0.01,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                onSelect: () =>
                    player.setSpeed(PlaybackSpeedSelector._speeds[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final VoidCallback onSelect;

  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.padding,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionChip(
      label: '${speed}x',
      selected: selected,
      expand: true,
      padding: padding,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect();
      },
    );
  }
}
