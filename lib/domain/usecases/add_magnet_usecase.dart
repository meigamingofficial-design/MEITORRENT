import '../repositories/torrent_repository.dart';

/// Validates and adds a magnet link to the engine.
class AddMagnetUsecase {
  const AddMagnetUsecase(this._repository);

  final TorrentRepository _repository;

  static final _magnetRegex = RegExp(
    r'^magnet:\?xt=urn:btih:[a-zA-Z0-9]{32,40}',
    caseSensitive: false,
  );

  /// Returns the torrent ID on success.
  /// Throws [ArgumentError] if the URI is invalid.
  Future<String> call(String magnetUri, {String? savePath}) {
    final trimmed = magnetUri.trim();
    if (!_magnetRegex.hasMatch(trimmed)) {
      throw ArgumentError('Invalid magnet URI: $trimmed');
    }
    return _repository.addMagnet(trimmed, savePath: savePath);
  }
}
