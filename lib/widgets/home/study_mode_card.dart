import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Home entry point for Study Mode — visible when [studyMode] flag is on.
class StudyModeCard extends StatelessWidget {
  const StudyModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.status != CatalogStatus.loaded) {
      return const SizedBox.shrink();
    }

    final study = context.watch<StudyProgressProvider>();
    final recommended = study.recommendedChapter;
    final l10n = context.l10n;
    final lang = context.read<LanguageProvider>();
    final actionLabel = _actionLabel(context, study, recommended, l10n, lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.studyMode,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.go('/study'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.groupedSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.groupedBorder, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.semantic.brandSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: context.brandColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.studyModeSubtitle(
                          study.studiedCount,
                          study.totalChapterCount,
                        ),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        actionLabel,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.mutedIconColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _actionLabel(
    BuildContext context,
    StudyProgressProvider study,
    Chapter? recommended,
    AppLocalizations l10n,
    LanguageProvider lang,
  ) {
    if (recommended == null) {
      return l10n.studyAllComplete;
    }

    final title = lang.resolve(recommended.title);
    final status = study.chapterStatus(recommended.id);
    return switch (status) {
      ChapterStudyStatus.inProgress => l10n.studyContinueClass(title),
      ChapterStudyStatus.notStarted => l10n.studyStartClass(title),
      ChapterStudyStatus.studied => l10n.studyOpenOverview,
    };
  }
}
