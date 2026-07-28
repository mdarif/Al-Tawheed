import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/study_progress_label.dart';
import 'package:myapp/widgets/study/parts_progress_bar.dart';
import 'package:myapp/widgets/study/study_status_chip.dart';

class ClassProgressCard extends StatelessWidget {
  final ChapterStudyInfo info;
  final VoidCallback onTap;

  const ClassProgressCard({
    super.key,
    required this.info,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chapter = info.chapter;
    final l10n = context.l10n;
    final studied = info.status == ChapterStudyStatus.studied;
    final semantic = context.semantic;

    final decoration = info.isRecommended
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: [
                semantic.accentGradientStart,
                semantic.accentGradientEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: context.brandColor.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: context.brandColor.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          )
        : BoxDecoration(
            color: context.groupedSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.groupedBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 5,
                offset: const Offset(0, 1),
              ),
            ],
          );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: decoration,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ChapterBadge(status: info.status, number: chapter.number),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (info.isRecommended) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 12,
                            color: context.brandColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.studyRecommendedNext,
                            style: context.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: context.brandColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            // Watch so the title refreshes on a UI-language
                            // change while Study Mode stays alive in the shell.
                            context
                                .watch<LanguageProvider>()
                                .resolve(chapter.title),
                            style: context.textTheme.titleSmall?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        StudyStatusChip(status: info.status),
                        if (info.isRecommended) ...[
                          const SizedBox(width: 8),
                          _RecommendedPlayCue(onTap: onTap),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: PartsProgressBar(
                            completed:
                                studied ? info.totalParts : info.completedParts,
                            total: info.totalParts,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context
                              .localizedDigits(studyProgressLabel(info, l10n)),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.secondaryTextColor,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedPlayCue extends StatelessWidget {
  final VoidCallback onTap;

  const _RecommendedPlayCue({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.studyStart,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.brandColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: context.onBrandColor,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ChapterBadge extends StatelessWidget {
  final ChapterStudyStatus status;
  final int number;

  const _ChapterBadge({required this.status, required this.number});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    final (background, foreground, border, borderWidth) = switch (status) {
      ChapterStudyStatus.studied => (
          context.brandColor,
          context.onBrandColor,
          context.brandColor,
          1.0,
        ),
      ChapterStudyStatus.inProgress => (
          semantic.brandSubtle,
          context.brandColor,
          context.brandColor,
          2.0,
        ),
      ChapterStudyStatus.notStarted => (
          Colors.transparent,
          context.primaryTextColor,
          context.surfaceTintColor,
          1.5,
        ),
    };

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: status == ChapterStudyStatus.studied
          ? Icon(Icons.check_rounded, color: foreground, size: 22)
          : Text(
              context.localizedDigits(number.toString().padLeft(2, '0')),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground,
                // The codepoints are only half the job — the face draws them.
                fontFamily: context.numeralFontFamily,
              ),
            ),
    );
  }
}
