import 'package:myapp/models/catalog.dart';

enum PlaybackMode { casual, study }

/// Whether the last part of a study session queue has finished.
bool shouldCompleteStudyChapter({
  required PlaybackMode mode,
  required int currentIndex,
  required int queueLength,
}) =>
    mode == PlaybackMode.study &&
    currentIndex >= 0 &&
    queueLength > 0 &&
    currentIndex >= queueLength - 1;

/// Label shown under the track title during a study session.
String? formatStudyContextLabel({
  required PlaybackMode mode,
  required Chapter? chapter,
  required int currentIndex,
  required int queueLength,
}) {
  if (mode != PlaybackMode.study || chapter == null || queueLength == 0) {
    return null;
  }
  final part = currentIndex >= 0 ? currentIndex + 1 : 1;
  return '${chapter.title} · Part $part of $queueLength';
}
