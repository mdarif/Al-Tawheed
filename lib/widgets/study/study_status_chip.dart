import 'package:flutter/material.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Status pill on the right side of a class progress card.
class StudyStatusChip extends StatelessWidget {
  final ChapterStudyStatus status;

  const StudyStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    final (label, icon, background, foreground, border) = switch (status) {
      ChapterStudyStatus.studied => (
          l10n.studyStatusStudied,
          null,
          context.brandColor,
          context.onBrandColor,
          context.brandColor,
        ),
      ChapterStudyStatus.inProgress => (
          l10n.studyStatusInProgress,
          null,
          semantic.brandSubtle,
          context.brandColor,
          semantic.accentGradientBorder,
        ),
      ChapterStudyStatus.notStarted => (
          l10n.studyStart,
          Icons.play_arrow_rounded,
          Colors.transparent,
          context.primaryTextColor,
          context.surfaceTintColor,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
