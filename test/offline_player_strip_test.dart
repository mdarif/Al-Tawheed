import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/audio/playback_source.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/utils/offline_player_strip.dart';

void main() {
  group('resolveOfflinePlayerStrip', () {
    test('downloading takes priority', () {
      expect(
        resolveOfflinePlayerStrip(
          source: PlaybackSource.stream,
          isStuck: false,
          isOffline: false,
          dlStatus: DownloadStatus.downloading,
          dlProgress: 0.42,
        )?.kind,
        OfflineStripKind.downloading,
      );
    });

    test('saved when downloaded', () {
      expect(
        resolveOfflinePlayerStrip(
          source: PlaybackSource.local,
          isStuck: false,
          isOffline: true,
          dlStatus: DownloadStatus.downloaded,
          dlProgress: 0,
        )?.kind,
        OfflineStripKind.saved,
      );
    });

    test('blocked shows not available offline', () {
      expect(
        resolveOfflinePlayerStrip(
          source: PlaybackSource.blocked,
          isStuck: false,
          isOffline: true,
          dlStatus: DownloadStatus.notDownloaded,
          dlProgress: 0,
        )?.kind,
        OfflineStripKind.notAvailableOffline,
      );
    });

    test('online streaming shows streaming strip', () {
      expect(
        resolveOfflinePlayerStrip(
          source: PlaybackSource.stream,
          isStuck: false,
          isOffline: false,
          dlStatus: DownloadStatus.notDownloaded,
          dlProgress: 0,
        )?.kind,
        OfflineStripKind.streaming,
      );
    });

    test('offline streaming shows no connection', () {
      expect(
        resolveOfflinePlayerStrip(
          source: PlaybackSource.stream,
          isStuck: false,
          isOffline: true,
          dlStatus: DownloadStatus.notDownloaded,
          dlProgress: 0,
        )?.kind,
        OfflineStripKind.noConnection,
      );
    });

    test('stuck buffering shows connection lost', () {
      expect(
        resolveOfflinePlayerStrip(
          source: PlaybackSource.stream,
          isStuck: true,
          isOffline: false,
          dlStatus: DownloadStatus.notDownloaded,
          dlProgress: 0,
        )?.kind,
        OfflineStripKind.connectionLost,
      );
    });

    test('online local file without download record returns null', () {
      expect(
        resolveOfflinePlayerStrip(
          source: PlaybackSource.local,
          isStuck: false,
          isOffline: false,
          dlStatus: DownloadStatus.notDownloaded,
          dlProgress: 0,
        ),
        isNull,
      );
    });
  });
}
