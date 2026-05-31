import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/domain/entities/torrent_status.dart';

void main() {
  // ─── TorrentStateX.isActive ────────────────────────────────────────────────

  group('TorrentStateX.isActive', () {
    const activeStates = [
      TorrentState.downloading,
      TorrentState.downloadingMetadata,
      TorrentState.seeding,
      TorrentState.finished,
      TorrentState.checkingFiles,
      TorrentState.checkingResume,
      TorrentState.allocating,
    ];

    for (final state in activeStates) {
      test('$state is active', () => expect(state.isActive, isTrue));
    }

    const inactiveStates = [
      TorrentState.paused,
      TorrentState.stopped,
      TorrentState.error,
      TorrentState.unknown,
    ];

    for (final state in inactiveStates) {
      test('$state is NOT active', () => expect(state.isActive, isFalse));
    }
  });

  // ─── TorrentStateX.isPausedState ───────────────────────────────────────────

  group('TorrentStateX.isPausedState', () {
    test('paused is a paused state', () {
      expect(TorrentState.paused.isPausedState, isTrue);
    });
    test('stopped is a paused state', () {
      expect(TorrentState.stopped.isPausedState, isTrue);
    });
    test('downloading is NOT a paused state', () {
      expect(TorrentState.downloading.isPausedState, isFalse);
    });
  });

  // ─── TorrentStateX.isFinished ──────────────────────────────────────────────

  group('TorrentStateX.isFinished', () {
    test('finished state is finished', () {
      expect(TorrentState.finished.isFinished, isTrue);
    });
    test('seeding state is finished', () {
      expect(TorrentState.seeding.isFinished, isTrue);
    });
    test('downloading is NOT finished', () {
      expect(TorrentState.downloading.isFinished, isFalse);
    });
  });

  // ─── TorrentStatusX.isEffectivelyComplete ─────────────────────────────────

  group('TorrentStatusX.isEffectivelyComplete', () {
    TorrentStatus make({
      required TorrentState state,
      int totalSize = 0,
      int downloadedBytes = 0,
      double progress = 0.0,
    }) => TorrentStatus(
      id: 'test-id',
      name: 'Test Torrent',
      progress: progress,
      downloadSpeed: 0,
      uploadSpeed: 0,
      peers: 0,
      seeds: 0,
      state: state,
      totalSize: totalSize,
      downloadedBytes: downloadedBytes,
      uploadedBytes: 0,
      savePath: '/sdcard/Downloads',
      addedAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
      ratio: 0.0,
    );

    test('seeding state is always effectively complete', () {
      final status = make(state: TorrentState.seeding, totalSize: 0);
      expect(status.isEffectivelyComplete, isTrue);
    });

    test('100% progress marks as effectively complete', () {
      final status = make(
        state: TorrentState.finished,
        progress: 1.0,
        totalSize: 1000,
        downloadedBytes: 1000,
      );
      expect(status.isEffectivelyComplete, isTrue);
    });

    test('downloadedBytes >= totalSize marks as complete', () {
      final status = make(
        state: TorrentState.finished,
        totalSize: 500,
        downloadedBytes: 500,
        progress: 0.99, // Slightly off — bytes should win
      );
      expect(status.isEffectivelyComplete, isTrue);
    });

    test(
      'zero totalSize with finished state is NOT complete by byte check',
      () {
        // Should NOT claim complete if totalSize=0 (metadata not loaded yet)
        final status = make(
          state: TorrentState.finished,
          totalSize: 0,
          downloadedBytes: 0,
          progress: 0.0,
        );
        // Only seeding triggers completion when totalSize==0
        expect(status.isEffectivelyComplete, isFalse);
      },
    );

    test('downloading 50% is NOT effectively complete', () {
      final status = make(
        state: TorrentState.downloading,
        totalSize: 1000,
        downloadedBytes: 500,
        progress: 0.5,
      );
      expect(status.isEffectivelyComplete, isFalse);
    });

    test('paused at 100% is effectively complete', () {
      final status = make(
        state: TorrentState.paused,
        progress: 1.0,
        totalSize: 1000,
        downloadedBytes: 1000,
      );
      expect(status.isEffectivelyComplete, isTrue);
    });
  });
}
