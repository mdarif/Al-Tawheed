import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';

/// Starts a chapter-scoped study playback session and opens the player.
void startStudySession(
  BuildContext context,
  String chapterId, {
  bool restartStudied = false,
  bool replaceRoute = false,
}) {
  final study = context.read<StudyProgressProvider>();
  final catalog = context.read<CatalogProvider>().catalog;
  if (catalog == null) return;

  final lecture = study.sessionStartLecture(
    chapterId,
    restartStudied: restartStudied,
  );
  if (lecture == null) return;

  Chapter chapter;
  try {
    chapter = catalog.chapterById(chapterId);
  } catch (_) {
    return;
  }

  final queue = study.chapterQueue(chapterId);
  context.read<PlayerNotifier>().startStudySession(
        lecture: lecture,
        queue: queue,
        chapter: chapter,
      );
  if (replaceRoute) {
    context.pushReplacement('/player');
  } else {
    context.push('/player');
  }
}
