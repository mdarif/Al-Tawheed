import 'package:myapp/audio/playback_source.dart';
import 'package:myapp/providers/downloads_provider.dart';

enum OfflineStripKind {
  downloading,
  saved,
  streaming,
  noConnection,
  connectionLost,
  notAvailableOffline,
}

class OfflineStripResolution {
  final OfflineStripKind kind;
  final int downloadPercent;

  const OfflineStripResolution(this.kind, {this.downloadPercent = 0});
}

/// Pure resolution for the player offline status strip — no BuildContext.
OfflineStripResolution? resolveOfflinePlayerStrip({
  required PlaybackSource source,
  required bool isStuck,
  required bool isOffline,
  required DownloadStatus dlStatus,
  required double dlProgress,
}) {
  if (dlStatus == DownloadStatus.downloading) {
    return OfflineStripResolution(
      OfflineStripKind.downloading,
      downloadPercent: (dlProgress * 100).round(),
    );
  }

  if (dlStatus == DownloadStatus.downloaded) {
    return OfflineStripResolution(OfflineStripKind.saved);
  }

  if (source == PlaybackSource.blocked) {
    return const OfflineStripResolution(OfflineStripKind.notAvailableOffline);
  }

  if (source == PlaybackSource.stream || source == PlaybackSource.local) {
    if (isStuck) {
      return const OfflineStripResolution(OfflineStripKind.connectionLost);
    }
    if (isOffline) {
      return const OfflineStripResolution(OfflineStripKind.noConnection);
    }
    if (source == PlaybackSource.stream) {
      return const OfflineStripResolution(OfflineStripKind.streaming);
    }
  }

  return null;
}
