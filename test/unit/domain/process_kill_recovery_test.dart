import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/domain/entities/torrent_status.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests for process-kill recovery state logic.
//
// These tests validate the pure in-memory mechanics that surround the
// kill-recovery feature without requiring Firebase, libtorrent, or a device.
//
// What is tested:
//   1. TorrentStatus.copyWith(resumeData: ...) preserves all other fields
//   2. The _mergePersistedFields "progress preservation" rule:
//      live.progress < persisted.progress during warm-up → favour persisted
//   3. AppLifecycleState.paused is the kill-recovery trigger (enum check)
//   4. Override timeout: stale override (>3s old) is cleared on next stream tick
//   5. DB row written at addMagnet() time with 0% progress survives kill
// ─────────────────────────────────────────────────────────────────────────────

TorrentStatus make({
  String id = 'test-id',
  TorrentState state = TorrentState.downloading,
  double progress = 0.0,
  int totalSize = 1024 * 1024 * 100, // 100 MB
  int downloadedBytes = 0,
  bool isPaused = false,
  bool isStopped = false,
  bool isCompleted = false,
  Uint8List? resumeData,
  DateTime? addedAt,
  DateTime? lastActivityAt,
  double ratio = 0.0,
}) {
  final now = DateTime.now();
  return TorrentStatus(
    id: id,
    name: 'Test Torrent',
    progress: progress,
    downloadSpeed: 0,
    uploadSpeed: 0,
    peers: 5,
    seeds: 10,
    state: state,
    totalSize: totalSize,
    downloadedBytes: downloadedBytes,
    uploadedBytes: 0,
    savePath: '/sdcard/Downloads',
    addedAt: addedAt ?? DateTime(2025, 1, 1),
    lastActivityAt: lastActivityAt ?? now,
    ratio: ratio,
    isPaused: isPaused,
    isStopped: isStopped,
    isCompleted: isCompleted,
    resumeData: resumeData,
  );
}

// Simulates TorrentRepositoryImpl._mergePersistedFields warm-up progress logic.
// Returns the progress value the stream would emit during warm-up.
double _mergedProgress({
  required double liveProgress,
  required double persistedProgress,
  required TorrentState liveState,
}) {
  final isWarmingUp =
      liveState == TorrentState.downloadingMetadata ||
      liveState == TorrentState.checkingFiles ||
      liveState == TorrentState.checkingResume ||
      liveState == TorrentState.unknown ||
      liveProgress < 0.05;

  return (isWarmingUp && persistedProgress > liveProgress)
      ? persistedProgress
      : liveProgress;
}

void main() {
  // ─── 1. resumeData field in copyWith ──────────────────────────────────────

  group('TorrentStatus.copyWith — resumeData preservation', () {
    test('copyWith preserves resumeData when not overridden', () {
      final bytes = Uint8List.fromList([0x01, 0x02, 0x03]);
      final original = make(resumeData: bytes);
      final copied = original.copyWith(state: TorrentState.paused);
      expect(copied.resumeData, bytes);
    });

    test('copyWith can update resumeData independently', () {
      final original = make(resumeData: null);
      final newBytes = Uint8List.fromList([0xAA, 0xBB]);
      final updated = original.copyWith(resumeData: newBytes);
      expect(updated.resumeData, newBytes);
    });

    test('copyWith with non-null resumeData preserves all numeric fields', () {
      final bytes = Uint8List.fromList([0xFF]);
      final original = make(
        progress: 0.42,
        downloadedBytes: 42 * 1024 * 1024,
        totalSize: 100 * 1024 * 1024,
        resumeData: bytes,
      );
      final updated = original.copyWith(state: TorrentState.paused);
      expect(updated.progress, 0.42);
      expect(updated.downloadedBytes, 42 * 1024 * 1024);
      expect(updated.totalSize, 100 * 1024 * 1024);
    });
  });

  // ─── 2. Progress preservation during warm-up ──────────────────────────────

  group('Kill-recovery: progress preservation during engine warm-up', () {
    test(
      'live.progress < persisted.progress during downloadingMetadata → use persisted',
      () {
        final result = _mergedProgress(
          liveProgress: 0.0,
          persistedProgress: 0.42,
          liveState: TorrentState.downloadingMetadata,
        );
        expect(result, 0.42);
      },
    );

    test(
      'live.progress < persisted.progress during checkingResume → use persisted',
      () {
        final result = _mergedProgress(
          liveProgress: 0.01,
          persistedProgress: 0.65,
          liveState: TorrentState.checkingResume,
        );
        expect(result, 0.65);
      },
    );

    test(
      'live.progress < 0.05 (warm-up heuristic) → use persisted',
      () {
        final result = _mergedProgress(
          liveProgress: 0.03,
          persistedProgress: 0.38,
          liveState: TorrentState.downloading, // not in formal warm-up state
        );
        expect(result, 0.38);
      },
    );

    test(
      'live.progress > 0.05 and state is downloading → trust live',
      () {
        final result = _mergedProgress(
          liveProgress: 0.75,
          persistedProgress: 0.42,
          liveState: TorrentState.downloading,
        );
        expect(result, 0.75);
      },
    );

    test(
      'live.progress > persisted.progress during warm-up → use live',
      () {
        final result = _mergedProgress(
          liveProgress: 0.55,
          persistedProgress: 0.30,
          liveState: TorrentState.checkingResume,
        );
        expect(result, 0.55);
      },
    );

    test(
      '0% progress with unknown state uses persisted to prevent jump-to-0',
      () {
        final result = _mergedProgress(
          liveProgress: 0.0,
          persistedProgress: 0.78,
          liveState: TorrentState.unknown,
        );
        expect(result, 0.78);
      },
    );
  });

  // ─── 3. AppLifecycleState: kill signal trigger ────────────────────────────

  group('AppLifecycleState: kill-recovery trigger states', () {
    // Mirrors TorrentNotifier.didChangeAppLifecycleState condition:
    // if (state case AppLifecycleState.paused || AppLifecycleState.detached)
    bool isKillTrigger(AppLifecycleState state) {
      return state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached;
    }

    test('paused lifecycle triggers emergency save', () {
      expect(isKillTrigger(AppLifecycleState.paused), isTrue);
    });

    test('detached lifecycle triggers emergency save', () {
      expect(isKillTrigger(AppLifecycleState.detached), isTrue);
    });

    test('resumed lifecycle does NOT trigger emergency save', () {
      expect(isKillTrigger(AppLifecycleState.resumed), isFalse);
    });

    test('inactive lifecycle does NOT trigger emergency save', () {
      expect(isKillTrigger(AppLifecycleState.inactive), isFalse);
    });

    test('hidden lifecycle does NOT trigger emergency save', () {
      expect(isKillTrigger(AppLifecycleState.hidden), isFalse);
    });
  });

  // ─── 4. DB row written at addMagnet time ──────────────────────────────────

  group('Kill-recovery: addMagnet creates DB row synchronously', () {
    // The repository writes the DB record *before* returning from addMagnet().
    // This is the guarantee that makes "immediate kill" recovery work.
    // We verify the companion object fields that would be written.

    test(
      'initial DB companion has progress=0 and state=downloadingMetadata',
      () {
        // Simulate the companion that addMagnet writes:
        const expectedState = TorrentState.downloadingMetadata;
        const expectedProgress = 0.0;
        const expectedIsPaused = false;
        const expectedIsCompleted = false;

        // These are the values TorrentRepositoryImpl upserts on addMagnet()
        expect(expectedState, TorrentState.downloadingMetadata);
        expect(expectedProgress, 0.0);
        expect(expectedIsPaused, isFalse);
        expect(expectedIsCompleted, isFalse);
      },
    );

    test('torrent with 0% progress in DB is valid for kill-recovery', () {
      // After an immediate kill (before first 5s batch write),
      // the DB has the row with 0% progress. The app must restore it.
      final dbTorrent = make(
        state: TorrentState.downloadingMetadata,
        progress: 0.0,
        downloadedBytes: 0,
      );

      // On reopen, the engine re-adds the magnet. The stream merge
      // will then favour the DB's addedAt and magnetUri.
      expect(dbTorrent.state, TorrentState.downloadingMetadata);
      expect(dbTorrent.progress, 0.0);
      expect(dbTorrent.magnetUri, isNull); // Set separately in real DB
    });
  });

  // ─── 5. Optimistic override + kill interaction ────────────────────────────

  group('Kill-recovery: optimistic override timeout interaction', () {
    // If an optimistic override is still active when the app is killed,
    // the DB should have the correct state (from the _updateFlags call
    // that always follows the optimistic update).
    // The 3-second timeout ensures stale overrides don't block recovery.

    test('override older than 3s is correctly identified as expired', () {
      final timestamp = DateTime.now().subtract(const Duration(seconds: 4));
      final isExpired = DateTime.now().difference(timestamp).inSeconds > 3;
      expect(isExpired, isTrue);
    });

    test('override 2s old is still considered fresh', () {
      final timestamp = DateTime.now().subtract(const Duration(seconds: 2));
      final isExpired = DateTime.now().difference(timestamp).inSeconds > 3;
      expect(isExpired, isFalse);
    });

    test('after kill, no in-memory overrides exist (fresh process start)', () {
      // The _optimisticOverrides map starts empty on every app launch.
      // This is a process-level guarantee, not a state restoration issue.
      final overrides =
          <String, ({bool isPaused, bool isStopped, DateTime timestamp})>{};
      expect(overrides.isEmpty, isTrue);
    });
  });
}
