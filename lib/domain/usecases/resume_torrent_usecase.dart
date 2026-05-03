import '../repositories/torrent_repository.dart';

class ResumeTorrentUsecase {
  const ResumeTorrentUsecase(this._repository);
  final TorrentRepository _repository;
  Future<void> call(String id) => _repository.resumeTorrent(id);
}
