import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/study_session.dart';
import 'package:myapp/widgets/study/overall_progress_summary.dart';

class StudyClassCompleteScreen extends StatelessWidget {
  final String chapterId;

  const StudyClassCompleteScreen({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>().catalog;
    final study = context.watch<StudyProgressProvider>();

    Chapter? chapter;
    if (catalog != null) {
      try {
        chapter = catalog.chapterById(chapterId);
      } catch (_) {
        chapter = null;
      }
    }

    final nextChapter = study.recommendedChapter;
    final title = chapter?.title.en ?? 'Class complete';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Class Complete'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: context.semantic.brandSubtle.withValues(
                alpha: context.isDarkTheme ? 0.35 : 0.55,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.brandColor.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 56, color: context.brandColor),
                const SizedBox(height: 16),
                Text(
                  '$title complete',
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Well done — keep going at your own pace.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OverallProgressSummary(
            studiedCount: study.studiedCount,
            totalCount: study.totalChapterCount,
          ),
          const SizedBox(height: 24),
          if (nextChapter != null) ...[
            FilledButton(
              onPressed: () => _continueToNext(context, nextChapter.id),
              child: Text('Continue to ${nextChapter.title}'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/study'),
              child: const Text('Back to Study overview'),
            ),
          ] else
            FilledButton(
              onPressed: () => context.go('/study'),
              child: const Text('Back to Study overview'),
            ),
        ],
      ),
    );
  }

  void _continueToNext(BuildContext context, String chapterId) {
    startStudySession(context, chapterId, replaceRoute: true);
  }
}
