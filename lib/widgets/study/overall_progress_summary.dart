import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Overall study progress — e.g. "3 of 15 classes studied".
class OverallProgressSummary extends StatelessWidget {
  final int studiedCount;
  final int totalCount;

  const OverallProgressSummary({
    super.key,
    required this.studiedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = totalCount == 0 ? 0.0 : studiedCount / totalCount;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.groupedBorder, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 5,
                  backgroundColor: context.progressTrackColor,
                  color: context.brandColor,
                ),
                Text(
                  '$studiedCount',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.studyModeSubtitle(studiedCount, totalCount),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  studiedCount == totalCount
                      ? l10n.studyOverallComplete
                      : l10n.studyOverallInProgress,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
