import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({super.key});

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerNotifier, _Snapshot>(
      selector: (_, player) => _Snapshot(
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
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: sliderValue.clamp(0.0, 1.0),
                onChangeStart: (v) => setState(() => _draggingValue = v),
                onChanged: (v) => setState(() => _draggingValue = v),
                onChangeEnd: (v) {
                  setState(() => _draggingValue = null);
                  context.read<PlayerNotifier>().seek(
                        Duration(
                          milliseconds:
                              (v * snapshot.durationSeconds * 1000).round(),
                        ),
                      );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.localizedTime(snapshot.positionSeconds),
                    style: context.textTheme.bodySmall,
                  ),
                  Text(
                    context.localizedTime(snapshot.durationSeconds),
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

class _Snapshot {
  final double progress;
  final int positionSeconds;
  final int durationSeconds;

  const _Snapshot({
    required this.progress,
    required this.positionSeconds,
    required this.durationSeconds,
  });

  @override
  bool operator ==(Object other) =>
      other is _Snapshot &&
      other.progress == progress &&
      other.positionSeconds == positionSeconds &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode => Object.hash(progress, positionSeconds, durationSeconds);
}
