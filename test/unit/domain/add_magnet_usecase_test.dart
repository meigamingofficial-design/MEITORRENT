import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meitorrent/domain/repositories/torrent_repository.dart';
import 'package:meitorrent/domain/usecases/add_magnet_usecase.dart';

class MockTorrentRepository extends Mock implements TorrentRepository {}

void main() {
  late MockTorrentRepository mockRepo;
  late AddMagnetUsecase usecase;

  setUp(() {
    mockRepo = MockTorrentRepository();
    usecase = AddMagnetUsecase(mockRepo);
  });

  // ─── Valid magnet URIs ─────────────────────────────────────────────────────

  group('AddMagnetUsecase — valid magnets', () {
    const validMagnet40 =
        'magnet:?xt=urn:btih:AABBCCDDEEFF00112233445566778899AABBCCDD&dn=Test';
    const validMagnet32 =
        'magnet:?xt=urn:btih:AABBCCDDEEFFAABBCCDDEEFFAABBCCDD&dn=Test';

    test('accepts 40-char hex info-hash magnet', () async {
      when(
        () => mockRepo.addMagnet(any(), savePath: any(named: 'savePath')),
      ).thenAnswer((_) async => 'torrent-id-1');

      final result = await usecase(validMagnet40);

      expect(result, 'torrent-id-1');
      verify(() => mockRepo.addMagnet(any(), savePath: null)).called(1);
    });

    test('accepts 32-char base32 info-hash magnet', () async {
      when(
        () => mockRepo.addMagnet(any(), savePath: any(named: 'savePath')),
      ).thenAnswer((_) async => 'torrent-id-2');

      final result = await usecase(validMagnet32);
      expect(result, 'torrent-id-2');
    });

    test('trims leading/trailing whitespace before validation', () async {
      when(
        () => mockRepo.addMagnet(any(), savePath: any(named: 'savePath')),
      ).thenAnswer((_) async => 'torrent-id-3');

      await usecase('  $validMagnet40  ');
      verify(() => mockRepo.addMagnet(any(), savePath: null)).called(1);
    });

    test('passes custom savePath to repository', () async {
      when(
        () => mockRepo.addMagnet(any(), savePath: '/sdcard/Downloads/custom'),
      ).thenAnswer((_) async => 'torrent-id-4');

      await usecase(validMagnet40, savePath: '/sdcard/Downloads/custom');
      verify(
        () => mockRepo.addMagnet(
          any(),
          savePath: '/sdcard/Downloads/custom',
        ),
      ).called(1);
    });
  });

  // ─── Invalid magnet URIs ───────────────────────────────────────────────────

  group('AddMagnetUsecase — invalid magnets', () {
    test('throws ArgumentError for empty string', () {
      expect(() => usecase(''), throwsArgumentError);
    });

    test('throws ArgumentError for plain URL', () {
      expect(
        () => usecase('https://example.com/file.torrent'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for malformed magnet (missing btih)', () {
      expect(
        () => usecase('magnet:?xt=urn:sha1:AABBCCDDEEFF'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for magnet with short hash (< 32 chars)', () {
      expect(
        () => usecase('magnet:?xt=urn:btih:AABBCCDD'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for random garbage string', () {
      expect(() => usecase('not a magnet at all'), throwsArgumentError);
    });

    test('does NOT call repository on invalid URI', () async {
      try {
        await usecase('invalid');
      } catch (_) {}
      verifyNever(
        () => mockRepo.addMagnet(any(), savePath: any(named: 'savePath')),
      );
    });
  });
}
