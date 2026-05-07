import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/domain/entities/torrent_status.dart';

void main() {
  group('TorrentStatus deepEquals', () {
    final base = TorrentStatus(
      id: 'abc123',
      name: 'Ubuntu 24.04',
      progress: 0.5,
      downloadSpeed: 1024 * 512,
      uploadSpeed: 1024 * 128,
      peers: 10,
      seeds: 30,
      state: TorrentState.downloading,
      totalSize: 1024 * 1024 * 1024,
      downloadedBytes: 512 * 1024 * 1024,
      uploadedBytes: 0,
      savePath: '/storage/downloads',
      addedAt: DateTime(2024, 1, 1),
      ratio: 0.0,
    );

    test('identical objects are equal', () {
      expect(base.deepEquals(base), isTrue);
    });

    test('copy with same fields is equal', () {
      final copy = base.copyWith();
      expect(base.deepEquals(copy), isTrue);
    });

    test('different progress triggers inequality', () {
      final changed = base.copyWith(progress: 0.7);
      expect(base.deepEquals(changed), isFalse);
    });

    test('different downloadSpeed triggers inequality', () {
      final changed = base.copyWith(downloadSpeed: 999);
      expect(base.deepEquals(changed), isFalse);
    });

    test('different state triggers inequality', () {
      final changed = base.copyWith(state: TorrentState.paused);
      expect(base.deepEquals(changed), isFalse);
    });

    test('different name triggers inequality', () {
      final changed = base.copyWith(name: 'Debian 12');
      expect(base.deepEquals(changed), isFalse);
    });

    test('different peers triggers inequality', () {
      final changed = base.copyWith(peers: 99);
      expect(base.deepEquals(changed), isFalse);
    });

    test('progress requires strict double equality', () {
      final almost = base.copyWith(progress: 0.5 + 0.000099);
      expect(base.deepEquals(almost), isFalse);
    });
  });

  group('TorrentState extensions', () {
    test('downloading isActive == true', () {
      expect(TorrentState.downloading.isActive, isTrue);
    });

    test('seeding isActive == true', () {
      expect(TorrentState.seeding.isActive, isTrue);
    });

    test('paused isActive == false', () {
      expect(TorrentState.paused.isActive, isFalse);
    });

    test('finished isFinished == true', () {
      expect(TorrentState.finished.isFinished, isTrue);
    });

    test('error hasError == true', () {
      expect(TorrentState.error.hasError, isTrue);
    });

    test('displayName for all states is non-empty', () {
      for (final state in TorrentState.values) {
        expect(state.displayName.isNotEmpty, isTrue);
      }
    });
  });
}
