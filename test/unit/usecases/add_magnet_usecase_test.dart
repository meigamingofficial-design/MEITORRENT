import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/domain/usecases/add_magnet_usecase.dart';
import 'package:meitorrent/domain/repositories/torrent_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockTorrentRepository extends Mock implements TorrentRepository {}

void main() {
  late MockTorrentRepository mockRepo;
  late AddMagnetUsecase usecase;

  setUp(() {
    mockRepo = MockTorrentRepository();
    usecase = AddMagnetUsecase(mockRepo);
  });

  group('AddMagnetUsecase validation', () {
    const validMagnet =
        'magnet:?xt=urn:btih:08ada5a7a6183aae1e09d831df6748d566095a10&dn=ubuntu';

    test('valid magnet — delegates to repository', () async {
      when(() => mockRepo.addMagnet(any(), savePath: any(named: 'savePath')))
          .thenAnswer((_) async => 'abc123');

      final id = await usecase(validMagnet);
      expect(id, 'abc123');
      verify(() => mockRepo.addMagnet(validMagnet, savePath: null)).called(1);
    });

    test('strips leading/trailing whitespace before validation', () async {
      when(() => mockRepo.addMagnet(any(), savePath: any(named: 'savePath')))
          .thenAnswer((_) async => 'def456');

      final id = await usecase('  $validMagnet  ');
      expect(id, 'def456');
    });

    test('empty string throws ArgumentError', () {
      expect(() => usecase(''), throwsArgumentError);
    });

    test('http URL throws ArgumentError', () {
      expect(() => usecase('https://example.com/file.torrent'), throwsArgumentError);
    });

    test('truncated hash throws ArgumentError', () {
      expect(() => usecase('magnet:?xt=urn:btih:short'), throwsArgumentError);
    });

    test('missing xt= parameter throws ArgumentError', () {
      expect(() => usecase('magnet:?dn=ubuntu&tr=http://tracker.example.com'), throwsArgumentError);
    });
  });
}
