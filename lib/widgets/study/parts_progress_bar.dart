import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

/// Row of segmented bars visualizing per-part completion within a class.
class PartsProgressBar extends StatelessWidget {
  final int completed;
  final int total;
  final double height;
  final double gap;

  const PartsProgressBar({
    super.key,
    required this.completed,
    required this.total,
    this.height = 5,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i < completed
                    ? context.brandColor
                    : context.progressTrackColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
