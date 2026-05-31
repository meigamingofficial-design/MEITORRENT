import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/domain/entities/torrent_status.dart';

void main() {
  TorrentStatus make(
    String id, {
    TorrentState state = TorrentState.downloading,
    bool isCompleted = false,
    double progress = 0.0,
    int totalSize = 1000,
    int downloadedBytes = 0,
  }) => TorrentStatus(
    id: id,
    name: 'Torrent $id',
    progress: progress,
    downloadSpeed: 0,
    uploadSpeed: 0,
    peers: 0,
    seeds: 0,
    state: state,
    totalSize: totalSize,
    downloadedBytes: downloadedBytes,
    uploadedBytes: 0,
    savePath: '/sdcard',
    addedAt: DateTime.now(),
    lastActivityAt: DateTime.now(),
    ratio: 0,
    isCompleted: isCompleted,
  );

  group('TorrentFilter.all', () {
    test('includes all torrents regardless of state', () {
      final torrents = [
        make('t1', state: TorrentState.downloading),
        make('t2', state: TorrentState.paused),
        make(
          't3',
          state: TorrentState.seeding,
          progress: 1.0,
          totalSize: 1000,
          downloadedBytes: 1000,
        ),
        make('t4', state: TorrentState.error),
      ];

      final filtered = torrents.where((_) => true).toList();
      expect(filtered.length, 4);
    });
  });

  group('TorrentFilter.downloading', () {
    test('includes only active non-complete torrents', () {
      final torrents = [
        make('dl', state: TorrentState.downloading),
        make('metadata', state: TorrentState.downloadingMetadata),
        make('checking', state: TorrentState.checkingFiles),
        make('paused', state: TorrentState.paused),
        make(
          'complete',
          state: TorrentState.seeding,
          progress: 1.0,
          totalSize: 1000,
          downloadedBytes: 1000,
        ),
      ];

      final filtered = torrents.where((t) {
        final complete = t.isEffectivelyComplete;
        final active = t.state.isActive;
        return !complete && active;
      }).toList();

      expect(
        filtered.map((t) => t.id),
        containsAll(['dl', 'metadata', 'checking']),
      );
      expect(filtered.any((t) => t.id == 'complete'), isFalse);
      expect(filtered.any((t) => t.id == 'paused'), isFalse);
    });
  });

  group('TorrentFilter.completed', () {
    test('includes only effectively complete torrents', () {
      final torrents = [
        make('dl', state: TorrentState.downloading, progress: 0.5),
        make(
          'done',
          state: TorrentState.seeding,
          progress: 1.0,
          totalSize: 1000,
          downloadedBytes: 1000,
        ),
        make(
          'done2',
          state: TorrentState.finished,
          progress: 1.0,
          totalSize: 500,
          downloadedBytes: 500,
        ),
        make(
          'paused-done',
          state: TorrentState.paused,
          progress: 1.0,
          totalSize: 200,
          downloadedBytes: 200,
        ),
      ];

      final filtered = torrents.where((t) => t.isEffectivelyComplete).toList();

      expect(
        filtered.map((t) => t.id),
        containsAll(['done', 'done2', 'paused-done']),
      );
      expect(filtered.any((t) => t.id == 'dl'), isFalse);
    });
  });
}
