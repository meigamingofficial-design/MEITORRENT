import '../repositories/torrent_repository.dart';

class DeleteTorrentUsecase {
  const DeleteTorrentUsecase(this._repository);
  final TorrentRepository _repository;

  Future<void> call(String id, {bool deleteFiles = false}) =>
      _repository.deleteTorrent(id, deleteFiles: deleteFiles);
}
