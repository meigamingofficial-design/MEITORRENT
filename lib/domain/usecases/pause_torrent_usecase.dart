import '../repositories/torrent_repository.dart';

class PauseTorrentUsecase {
  const PauseTorrentUsecase(this._repository);
  final TorrentRepository _repository;
  Future<void> call(String id) => _repository.pauseTorrent(id);
}
