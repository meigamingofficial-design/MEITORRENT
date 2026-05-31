import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/domain/entities/torrent_status.dart';

/// Tests the sort-priority algorithm used by filteredTorrents provider.
///
/// The rule: active downloads (priority 0) must always sort above paused
/// (priority 4), stopped (5), error (6), unknown (7), and seeding/finished
/// comes in between.
void main() {
  // Mirror the sort priority function from torrent_notifier.dart
  int sortPriority(TorrentState state) => switch (state) {
    TorrentState.downloading => 0,
    TorrentState.downloadingMetadata => 0,
    TorrentState.checkingFiles => 1,
    TorrentState.checkingResume => 1,
    TorrentState.allocating => 1,
    TorrentState.seeding => 2,
    TorrentState.finished => 3,
    TorrentState.paused => 4,
    TorrentState.stopped => 5,
    TorrentState.error => 6,
    _ => 7,
  };

  group('Torrent sort priority', () {
    test('downloading has highest priority (0)', () {
      expect(sortPriority(TorrentState.downloading), 0);
    });

    test('downloadingMetadata has same priority as downloading', () {
      expect(
        sortPriority(TorrentState.downloadingMetadata),
        sortPriority(TorrentState.downloading),
      );
    });

    test('checking states have priority 1', () {
      expect(sortPriority(TorrentState.checkingFiles), 1);
      expect(sortPriority(TorrentState.checkingResume), 1);
      expect(sortPriority(TorrentState.allocating), 1);
    });

    test('seeding (2) comes before finished (3)', () {
      expect(
        sortPriority(TorrentState.seeding),
        lessThan(sortPriority(TorrentState.finished)),
      );
    });

    test('finished (3) comes before paused (4)', () {
      expect(
        sortPriority(TorrentState.finished),
        lessThan(sortPriority(TorrentState.paused)),
      );
    });

    test('paused (4) comes before stopped (5)', () {
      expect(
        sortPriority(TorrentState.paused),
        lessThan(sortPriority(TorrentState.stopped)),
      );
    });

    test('stopped (5) comes before error (6)', () {
      expect(
        sortPriority(TorrentState.stopped),
        lessThan(sortPriority(TorrentState.error)),
      );
    });

    test('unknown gets lowest priority (7)', () {
      expect(sortPriority(TorrentState.unknown), 7);
    });
  });

  group('Stable sort correctness', () {
    TorrentStatus make(String id, TorrentState state, DateTime addedAt) =>
        TorrentStatus(
          id: id,
          name: id,
          progress: 0,
          downloadSpeed: 0,
          uploadSpeed: 0,
          peers: 0,
          seeds: 0,
          state: state,
          totalSize: 0,
          downloadedBytes: 0,
          uploadedBytes: 0,
          savePath: '/sdcard',
          addedAt: addedAt,
          lastActivityAt: addedAt,
          ratio: 0,
        );

    test('active torrent bubbles above paused in sorted list', () {
      final now = DateTime.now();
      final torrents = [
        make(
          'paused-1',
          TorrentState.paused,
          now.subtract(const Duration(minutes: 1)),
        ),
        make('dl-1', TorrentState.downloading, now),
      ];

      torrents.sort((a, b) {
        final ap = sortPriority(a.state);
        final bp = sortPriority(b.state);
        if (ap != bp) return ap.compareTo(bp);
        return b.addedAt.compareTo(a.addedAt);
      });

      expect(torrents.first.id, 'dl-1');
      expect(torrents.last.id, 'paused-1');
    });

    test('two downloading torrents maintain stable order by addedAt', () {
      final now = DateTime.now();
      final earlier = now.subtract(const Duration(hours: 1));

      final torrents = [
        make('dl-old', TorrentState.downloading, earlier),
        make('dl-new', TorrentState.downloading, now),
      ];

      torrents.sort((a, b) {
        final ap = sortPriority(a.state);
        final bp = sortPriority(b.state);
        if (ap != bp) return ap.compareTo(bp);
        return b.addedAt.compareTo(a.addedAt); // newest first on tie
      });

      // Newest (dl-new) should come first when both downloading
      expect(torrents.first.id, 'dl-new');
    });
  });
}
