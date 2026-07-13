import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/study_session.dart';
import 'package:myapp/widgets/app_overflow_menu.dart';
import 'package:myapp/widgets/catalog_connect_required.dart';
import 'package:myapp/widgets/catalog_error_body.dart';
import 'package:myapp/widgets/confirm_dialog.dart';
import 'package:myapp/widgets/study/class_progress_card.dart';
import 'package:myapp/widgets/study/study_dashboard_card.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  // See the matching helper in LectureListScreen — reloads the catalog once
  // per distinct series id so Study Mode never shows a different series'
  // classes than the one currently active.
  String? _requestedSeriesId;

  void _syncCatalogToSeries(BuildContext context) {
    final series = context.watch<SeriesProvider>().currentSeries;
    if (series.id == _requestedSeriesId) return;
    _requestedSeriesId = series.id;

    final catalog = context.read<CatalogProvider>();
    if (catalog.loadedSeriesId == series.id) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogProvider>().load(series);
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncCatalogToSeries(context);
    final catalog = context.watch<CatalogProvider>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyMode),
        actions: const [AppOverflowMenu()],
      ),
      body: switch (catalog.status) {
        CatalogStatus.idle || CatalogStatus.loading => Center(
            child: CircularProgressIndicator(color: context.brandColor),
          ),
        CatalogStatus.error => catalog.needsOnlineToLoad
            ? CatalogConnectRequiredBody(provider: catalog)
            : CatalogErrorBody(
                icon: Icons.wifi_off_rounded,
                title: l10n.studyCouldNotLoadClasses,
                message: catalog.error ?? l10n.studyCouldNotLoadClasses,
                onRetry: () => catalog.load(),
              ),
        CatalogStatus.loaded => _StudyBody(
            onClassTap: (info) => _onClassTap(context, info),
          ),
      },
    );
  }

  Future<void> _onClassTap(BuildContext context, ChapterStudyInfo info) async {
    final l10n = context.l10n;
    final lang = context.read<LanguageProvider>();
    final title = lang.resolve(info.chapter.title);

    if (info.status == ChapterStudyStatus.studied) {
      final restart = await showConfirmDialog(
        context,
        title: l10n.studyRestartTitle(title),
        message: l10n.studyRestartMessage,
        confirmLabel: l10n.studyRestart,
        filledConfirm: true,
      );
      if (!restart || !context.mounted) return;
      startStudySession(context, info.chapter.id, restartStudied: true);
      return;
    }

    startStudySession(context, info.chapter.id);
  }
}

class _StudyBody extends StatelessWidget {
  final ValueChanged<ChapterStudyInfo> onClassTap;

  const _StudyBody({required this.onClassTap});

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProgressProvider>();
    final infos = study.chapterInfos();
    final stats = study.stats;
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        StudyDashboardCard(
          studiedCount: study.studiedCount,
          totalChapterCount: study.totalChapterCount,
          completedLectures: stats.completedLectures,
          totalLectures: stats.totalLectures,
          completedSeconds: stats.completedSeconds,
          totalSeconds: stats.totalSeconds,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.studyClasses,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final info in infos) ...[
          ClassProgressCard(
            info: info,
            onTap: () => onClassTap(info),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

