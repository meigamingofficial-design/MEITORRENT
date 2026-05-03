import 'package:equatable/equatable.dart';

/// Represents the possible states of a torrent.
/// Aligned with libtorrent_flutter 1.8.5 reference.
enum TorrentState {
  unknown,
  checkingFiles,
  downloadingMetadata,
  downloading,
  finished,
  seeding,
  allocating,
  checkingResume,
  paused, // Custom added for UI
  error,
}

extension TorrentStateX on TorrentState {
  String get displayName {
    switch (this) {
      case TorrentState.unknown:
        return 'Unknown';
      case TorrentState.checkingFiles:
        return 'Checking Files';
      case TorrentState.downloadingMetadata:
        return 'Fetching Metadata';
      case TorrentState.downloading:
        return 'Downloading';
      case TorrentState.finished:
        return 'Finished';
      case TorrentState.seeding:
        return 'Seeding';
      case TorrentState.allocating:
        return 'Allocating';
      case TorrentState.checkingResume:
        return 'Checking Resume';
      case TorrentState.paused:
        return 'Paused';
      case TorrentState.error:
        return 'Error';
    }
  }

  bool get isActive =>
      this == TorrentState.downloading ||
      this == TorrentState.downloadingMetadata ||
      this == TorrentState.seeding ||
      this == TorrentState.finished ||
      this == TorrentState.checkingFiles ||
      this == TorrentState.checkingResume ||
      this == TorrentState.allocating;

  bool get isFinished =>
      this == TorrentState.finished || this == TorrentState.seeding;

  bool get hasError => this == TorrentState.error;
}

extension TorrentStatusX on TorrentStatus {
  /// Uses actual transfer data to decide whether a torrent is truly complete.
  ///
  /// This protects the UI from transient engine flags that can briefly report
  /// a magnet as finished before real payload bytes are present.
  bool get isEffectivelyComplete {
    if (state == TorrentState.seeding) {
      return true;
    }
    if (progress >= 0.999) {
      return true;
    }
    if (totalSize > 0 && downloadedBytes >= totalSize) {
      return true;
    }
    return false;
  }
}

/// Domain model representing the current status of a torrent.
///
/// Throttled snapshots of this class are streamed from the [TorrentEngineService].
class TorrentStatus extends Equatable {
  final String id;
  final String name;
  final double progress; // 0.0 - 1.0
  final int downloadSpeed; // bytes/sec
  final int uploadSpeed; // bytes/sec
  final int peers;
  final int seeds;
  final TorrentState state;
  final int totalSize; // bytes
  final int downloadedBytes;
  final int uploadedBytes;
  final String savePath;
  final DateTime addedAt;
  final double ratio;
  final int? etaSeconds;
  final String? errorMessage;
  final String? magnetUri;
  final String? torrentFilePath;
  final bool isPaused;
  final bool isCompleted;
  final bool isSequentialDownload;

  const TorrentStatus({
    required this.id,
    required this.name,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.peers,
    required this.seeds,
    required this.state,
    required this.totalSize,
    required this.downloadedBytes,
    required this.uploadedBytes,
    required this.savePath,
    required this.addedAt,
    required this.ratio,
    this.etaSeconds,
    this.errorMessage,
    this.magnetUri,
    this.torrentFilePath,
    this.isPaused = false,
    this.isCompleted = false,
    this.isSequentialDownload = false,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        progress,
        downloadSpeed,
        uploadSpeed,
        peers,
        seeds,
        state,
        totalSize,
        downloadedBytes,
        uploadedBytes,
        savePath,
        addedAt,
        ratio,
        etaSeconds,
        errorMessage,
        magnetUri,
        torrentFilePath,
        isPaused,
        isCompleted,
        isSequentialDownload,
      ];

  /// Usesprops for deep equality comparison.
  bool deepEquals(TorrentStatus other) {
    return id == other.id &&
        name == other.name &&
        progress == other.progress &&
        downloadSpeed == other.downloadSpeed &&
        uploadSpeed == other.uploadSpeed &&
        peers == other.peers &&
        seeds == other.seeds &&
        state == other.state &&
        totalSize == other.totalSize &&
        downloadedBytes == other.downloadedBytes &&
        uploadedBytes == other.uploadedBytes &&
        savePath == other.savePath &&
        addedAt.millisecondsSinceEpoch ==
            other.addedAt.millisecondsSinceEpoch &&
        ratio == other.ratio &&
        etaSeconds == other.etaSeconds &&
        errorMessage == other.errorMessage &&
        magnetUri == other.magnetUri &&
        torrentFilePath == other.torrentFilePath &&
        isPaused == other.isPaused &&
        isCompleted == other.isCompleted &&
        isSequentialDownload == other.isSequentialDownload;
  }

  TorrentStatus copyWith({
    String? id,
    String? name,
    double? progress,
    int? downloadSpeed,
    int? uploadSpeed,
    int? peers,
    int? seeds,
    TorrentState? state,
    int? totalSize,
    int? downloadedBytes,
    int? uploadedBytes,
    String? savePath,
    DateTime? addedAt,
    double? ratio,
    int? etaSeconds,
    String? errorMessage,
    String? magnetUri,
    String? torrentFilePath,
    bool? isPaused,
    bool? isCompleted,
    bool? isSequentialDownload,
  }) {
    return TorrentStatus(
      id: id ?? this.id,
      name: name ?? this.name,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      peers: peers ?? this.peers,
      seeds: seeds ?? this.seeds,
      state: state ?? this.state,
      totalSize: totalSize ?? this.totalSize,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      savePath: savePath ?? this.savePath,
      addedAt: addedAt ?? this.addedAt,
      ratio: ratio ?? this.ratio,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      errorMessage: errorMessage ?? this.errorMessage,
      magnetUri: magnetUri ?? this.magnetUri,
      torrentFilePath: torrentFilePath ?? this.torrentFilePath,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
      isSequentialDownload: isSequentialDownload ?? this.isSequentialDownload,
    );
  }
}
