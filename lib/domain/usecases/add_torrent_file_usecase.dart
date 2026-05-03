import 'dart:io';

import '../repositories/torrent_repository.dart';

/// Validates a .torrent file exists and adds it to the engine.
class AddTorrentFileUsecase {
  const AddTorrentFileUsecase(this._repository);

  final TorrentRepository _repository;

  /// Returns the torrent ID on success.
  /// Throws [ArgumentError] if the file doesn't exist or is not a .torrent file.
  Future<String> call(String filePath, {String? savePath}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('Torrent file not found: $filePath');
    }
    if (!filePath.toLowerCase().endsWith('.torrent')) {
      throw ArgumentError('File is not a .torrent: $filePath');
    }
    return _repository.addTorrentFile(filePath, savePath: savePath);
  }
}
