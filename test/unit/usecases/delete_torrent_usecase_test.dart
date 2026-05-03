import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/domain/usecases/delete_torrent_usecase.dart';
import 'package:meitorrent/domain/repositories/torrent_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockTorrentRepository extends Mock implements TorrentRepository {}

void main() {
  late MockTorrentRepository mockRepo;
  late DeleteTorrentUsecase usecase;

  setUp(() {
    mockRepo = MockTorrentRepository();
    usecase = DeleteTorrentUsecase(mockRepo);
  });

  test('calls repository deleteTorrent with deleteFiles=false by default', () async {
    when(() => mockRepo.deleteTorrent(any(), deleteFiles: any(named: 'deleteFiles')))
        .thenAnswer((_) async {});

    await usecase('abc123');
    verify(() => mockRepo.deleteTorrent('abc123', deleteFiles: false)).called(1);
  });

  test('calls repository deleteTorrent with deleteFiles=true when specified', () async {
    when(() => mockRepo.deleteTorrent(any(), deleteFiles: any(named: 'deleteFiles')))
        .thenAnswer((_) async {});

    await usecase('abc123', deleteFiles: true);
    verify(() => mockRepo.deleteTorrent('abc123', deleteFiles: true)).called(1);
  });
}
