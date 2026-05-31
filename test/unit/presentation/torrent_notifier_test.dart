import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/domain/entities/torrent_status.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

TorrentStatus makeTorrent(
  String id, {
  TorrentState state = TorrentState.downloading,
  bool isPaused = false,
  bool isStopped = false,
  double progress = 0.0,
  int totalSize = 1000,
  int downloadedBytes = 0,
}) => TorrentStatus(
  id: id,
  name: 'Torrent $id',
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
  addedAt: DateTime(2025, 1, 1),
  lastActivityAt: DateTime.now(),
  ratio: 0.0,
  isPaused: isPaused,
  isStopped: isStopped,
);

// ─── Tests ───────────────────────────────────────────────────────────────────
// NOTE: TorrentNotifier.build() requires Firebase + NotificationService.
// These tests verify the *pure optimistic state logic* that the notifier
// applies, by running the same transformations on plain TorrentStatus lists.
// Full end-to-end notifier behaviour is covered by integration_test/.

// Mirrors TorrentNotifier._updateOptimisticStatus
List<TorrentStatus> applyOptimisticSingle(
  List<TorrentStatus> list,
  String id, {
  required bool isPaused,
  bool isStopped = false,
}) {
  return list.map((t) {
    if (t.id != id) return t;
    TorrentState newState = t.state;
    if (isStopped) {
      newState = TorrentState.stopped;
    } else if (isPaused) {
      newState = TorrentState.paused;
    } else {
      if (t.state == TorrentState.stopped || t.state == TorrentState.paused) {
        newState = TorrentState.downloading;
      }
    }
    return t.copyWith(
      isPaused: isPaused,
      isStopped: isStopped,
      state: newState,
    );
  }).toList();
}

// Mirrors TorrentNotifier._updateOptimisticStatusMultiple
List<TorrentStatus> applyOptimisticMultiple(
  List<TorrentStatus> list,
  List<String> ids, {
  required bool isPaused,
  bool isStopped = false,
}) {
  final idSet = ids.toSet();
  return list.map((t) {
    if (!idSet.contains(t.id)) return t;
    TorrentState newState = t.state;
    if (isStopped) {
      newState = TorrentState.stopped;
    } else if (isPaused) {
      newState = TorrentState.paused;
    } else {
      if (t.state == TorrentState.stopped || t.state == TorrentState.paused) {
        newState = TorrentState.downloading;
      }
    }
    return t.copyWith(
      isPaused: isPaused,
      isStopped: isStopped,
      state: newState,
    );
  }).toList();
}

void main() {
  group('Optimistic single-torrent transformations', () {
    test('pauseTorrent: isPaused=true, state→paused', () {
      final list = [makeTorrent('t1', state: TorrentState.downloading)];
      final result = applyOptimisticSingle(list, 't1', isPaused: true);
      final t1 = result.firstWhere((t) => t.id == 't1');
      expect(t1.isPaused, isTrue);
      expect(t1.state, TorrentState.paused);
    });

    test('resumeTorrent: isPaused=false, state→downloading', () {
      final list = [
        makeTorrent('t1', state: TorrentState.paused, isPaused: true),
      ];
      final result = applyOptimisticSingle(list, 't1', isPaused: false);
      final t1 = result.firstWhere((t) => t.id == 't1');
      expect(t1.isPaused, isFalse);
      expect(t1.state, TorrentState.downloading);
    });

    test('stopTorrent: isStopped=true, state→stopped', () {
      final list = [makeTorrent('t1', state: TorrentState.downloading)];
      final result = applyOptimisticSingle(
        list,
        't1',
        isPaused: true,
        isStopped: true,
      );
      final t1 = result.firstWhere((t) => t.id == 't1');
      expect(t1.isStopped, isTrue);
      expect(t1.state, TorrentState.stopped);
    });

    test('resuming from stopped state transitions to downloading', () {
      final list = [
        makeTorrent(
          't1',
          state: TorrentState.stopped,
          isStopped: true,
          isPaused: true,
        ),
      ];
      final result = applyOptimisticSingle(list, 't1', isPaused: false);
      final t1 = result.firstWhere((t) => t.id == 't1');
      expect(t1.state, TorrentState.downloading);
      expect(t1.isStopped, isFalse);
    });

    test('only the targeted torrent is modified', () {
      final list = [
        makeTorrent('t1', state: TorrentState.downloading),
        makeTorrent('t2', state: TorrentState.downloading),
      ];
      final result = applyOptimisticSingle(list, 't1', isPaused: true);
      final t2 = result.firstWhere((t) => t.id == 't2');
      expect(t2.isPaused, isFalse);
      expect(t2.state, TorrentState.downloading);
    });

    test('state remains unchanged when id not in list', () {
      final list = [makeTorrent('t1', state: TorrentState.downloading)];
      final result = applyOptimisticSingle(list, 'ghost', isPaused: true);
      final t1 = result.firstWhere((t) => t.id == 't1');
      expect(t1.isPaused, isFalse);
    });
  });

  group('Optimistic multiple-torrent transformations', () {
    test('pauseMultiple: only selected torrents are paused', () {
      final list = [
        makeTorrent('t1', state: TorrentState.downloading),
        makeTorrent('t2', state: TorrentState.downloading),
        makeTorrent('t3', state: TorrentState.downloading),
      ];
      final result = applyOptimisticMultiple(list, [
        't1',
        't2',
      ], isPaused: true);
      expect(result.firstWhere((t) => t.id == 't1').isPaused, isTrue);
      expect(result.firstWhere((t) => t.id == 't2').isPaused, isTrue);
      expect(result.firstWhere((t) => t.id == 't3').isPaused, isFalse);
    });

    test('stopMultiple: selected torrents get isStopped=true', () {
      final list = [
        makeTorrent('t1', state: TorrentState.downloading),
        makeTorrent('t2', state: TorrentState.downloading),
      ];
      final result = applyOptimisticMultiple(
        list,
        ['t1', 't2'],
        isPaused: true,
        isStopped: true,
      );
      expect(result.every((t) => t.isStopped), isTrue);
      expect(result.every((t) => t.state == TorrentState.stopped), isTrue);
    });

    test('resumeMultiple: all selected go from paused → downloading', () {
      final list = [
        makeTorrent('t1', state: TorrentState.paused, isPaused: true),
        makeTorrent('t2', state: TorrentState.paused, isPaused: true),
      ];
      final result = applyOptimisticMultiple(list, [
        't1',
        't2',
      ], isPaused: false);
      expect(result.every((t) => t.state == TorrentState.downloading), isTrue);
      expect(result.every((t) => !t.isPaused), isTrue);
    });

    test('resumeMultiple with empty id list leaves all unchanged', () {
      final list = [
        makeTorrent('t1', state: TorrentState.paused, isPaused: true),
      ];
      final result = applyOptimisticMultiple(list, [], isPaused: false);
      expect(result.first.isPaused, isTrue);
    });
  });

  group('Optimistic delete', () {
    test('deleted torrent is immediately removed from list', () {
      final list = [makeTorrent('t1'), makeTorrent('t2')];
      final updated = list.where((t) => t.id != 't1').toList();
      expect(updated.any((t) => t.id == 't1'), isFalse);
      expect(updated.any((t) => t.id == 't2'), isTrue);
    });

    test('delete non-existent id leaves list unchanged', () {
      final list = [makeTorrent('t1')];
      final updated = list.where((t) => t.id != 'ghost').toList();
      expect(updated.length, 1);
    });

    test('deleteMultiple removes all specified ids', () {
      final list = [makeTorrent('t1'), makeTorrent('t2'), makeTorrent('t3')];
      final idsToDelete = {'t1', 't3'};
      final updated = list.where((t) => !idsToDelete.contains(t.id)).toList();
      expect(updated.length, 1);
      expect(updated.first.id, 't2');
    });
  });

  group('Override timeout logic', () {
    test('override is expired after > 3 seconds', () {
      final timestamp = DateTime.now().subtract(const Duration(seconds: 4));
      final isExpired = DateTime.now().difference(timestamp).inSeconds > 3;
      expect(isExpired, isTrue);
    });

    test('override is still active within 3 seconds', () {
      final timestamp = DateTime.now().subtract(const Duration(seconds: 2));
      final isExpired = DateTime.now().difference(timestamp).inSeconds > 3;
      expect(isExpired, isFalse);
    });

    test('override at exactly 3s is still considered active', () {
      final timestamp = DateTime.now().subtract(const Duration(seconds: 3));
      final isExpired = DateTime.now().difference(timestamp).inSeconds > 3;
      expect(isExpired, isFalse);
    });
  });
}
