import 'torrent_status.dart';

/// Core domain entity representing a persisted torrent entry.
class Torrent {
  const Torrent({
    required this.id,
    required this.name,
    required this.savePath,
    required this.addedAt,
    this.magnetUri,
    this.torrentFilePath,
    this.totalSize = 0,
    this.downloadedBytes = 0,
    this.progress = 0.0,
    this.state = TorrentState.unknown,
    this.isSequentialDownload = false,
  });

  final String id;
  final String name;
  final String savePath;
  final DateTime addedAt;
  final String? magnetUri;
  final String? torrentFilePath;
  final int totalSize;
  final int downloadedBytes;
  final double progress;
  final TorrentState state;
  final bool isSequentialDownload;

  Torrent copyWith({
    String? id,
    String? name,
    String? savePath,
    DateTime? addedAt,
    String? magnetUri,
    String? torrentFilePath,
    int? totalSize,
    int? downloadedBytes,
    double? progress,
    TorrentState? state,
    bool? isSequentialDownload,
  }) {
    return Torrent(
      id: id ?? this.id,
      name: name ?? this.name,
      savePath: savePath ?? this.savePath,
      addedAt: addedAt ?? this.addedAt,
      magnetUri: magnetUri ?? this.magnetUri,
      torrentFilePath: torrentFilePath ?? this.torrentFilePath,
      totalSize: totalSize ?? this.totalSize,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      progress: progress ?? this.progress,
      state: state ?? this.state,
      isSequentialDownload: isSequentialDownload ?? this.isSequentialDownload,
    );
  }
}
