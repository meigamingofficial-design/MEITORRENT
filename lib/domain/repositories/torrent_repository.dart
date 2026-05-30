import '../entities/torrent_status.dart';

/// Abstract repository contract for all torrent operations.
/// The implementation wires together the engine and the local DB.
abstract interface class TorrentRepository {
  /// Live stream of all torrent statuses.
  /// Emits deduplicated (deep-equal) updates every ~500ms.
  Stream<List<TorrentStatus>> get statusStream;

  /// Returns the last known snapshot from the local DB.
  Future<List<TorrentStatus>> getStoredTorrents();

  /// Adds a torrent by magnet URI. Returns the torrent ID.
  Future<String> addMagnet(String uri, {String? savePath});

  /// Adds a torrent by .torrent file path. Returns the torrent ID.
  Future<String> addTorrentFile(String filePath, {String? savePath});

  /// Pauses an active torrent.
  Future<void> pauseTorrent(String id);

  /// Stops a torrent (Hard Pause).
  Future<void> stopTorrent(String id);

  /// Resumes a paused/stopped torrent.
  Future<void> resumeTorrent(String id);

  /// Removes a torrent. Optionally deletes downloaded files.
  Future<void> deleteTorrent(String id, {bool deleteFiles = false});

  /// ── Bulk Actions ──

  /// Pauses all active torrents.
  Future<void> pauseAll();

  /// Pauses specific torrents by ID.
  Future<void> pauseMultiple(List<String> ids);

  /// Stops all active torrents.
  Future<void> stopAll();

  /// Stops specific torrents by ID.
  Future<void> stopMultiple(List<String> ids);

  /// Resumes all paused/stopped torrents.
  Future<void> resumeAll();

  /// Resumes specific torrents by ID.
  Future<void> resumeMultiple(List<String> ids);

  /// Deletes multiple torrents by ID.
  Future<void> deleteMultiple(List<String> ids, {bool deleteFiles = false});

  /// Forces a piece-hash recheck on a partially downloaded torrent.
  Future<void> recheckTorrent(String id);

  /// Updates engine-wide configuration (speed limits, DHT, etc.).
  Future<void> applyEngineConfig(EngineConfig config);

  /// Forces an immediate capture and DB write of fast-resume data for all
  /// active torrents. Call this on app background/exit.
  Future<void> forceSaveAllResumeData();
}

/// Value object for libtorrent engine configuration.
class EngineConfig {
  const EngineConfig({
    this.downloadLimit = 0,
    this.uploadLimit = 0,
    this.maxConnectionsPerTorrent = 200,
    this.maxGlobalConnections = 500,
    this.dhtEnabled = true,
    this.pexEnabled = true,
    this.lsdEnabled = true,
    this.wifiOnlyMode = false,
    this.stopSeedingWhenFinished = true,
    this.defaultSavePath,
  });

  /// bytes/sec, 0 = unlimited
  final int downloadLimit;

  /// bytes/sec, 0 = unlimited
  final int uploadLimit;

  final int maxConnectionsPerTorrent;
  final int maxGlobalConnections;
  final bool dhtEnabled;
  final bool pexEnabled;
  final bool lsdEnabled;
  final bool wifiOnlyMode;
  final bool stopSeedingWhenFinished;

  /// Global default download directory. Null = engine default.
  final String? defaultSavePath;

  EngineConfig copyWith({
    int? downloadLimit,
    int? uploadLimit,
    int? maxConnectionsPerTorrent,
    int? maxGlobalConnections,
    bool? dhtEnabled,
    bool? pexEnabled,
    bool? lsdEnabled,
    bool? wifiOnlyMode,
    bool? stopSeedingWhenFinished,
    String? defaultSavePath,
    bool clearSavePath = false,
  }) {
    return EngineConfig(
      downloadLimit: downloadLimit ?? this.downloadLimit,
      uploadLimit: uploadLimit ?? this.uploadLimit,
      maxConnectionsPerTorrent:
          maxConnectionsPerTorrent ?? this.maxConnectionsPerTorrent,
      maxGlobalConnections: maxGlobalConnections ?? this.maxGlobalConnections,
      dhtEnabled: dhtEnabled ?? this.dhtEnabled,
      pexEnabled: pexEnabled ?? this.pexEnabled,
      lsdEnabled: lsdEnabled ?? this.lsdEnabled,
      wifiOnlyMode: wifiOnlyMode ?? this.wifiOnlyMode,
      stopSeedingWhenFinished:
          stopSeedingWhenFinished ?? this.stopSeedingWhenFinished,
      defaultSavePath: clearSavePath ? null : (defaultSavePath ?? this.defaultSavePath),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineConfig &&
          downloadLimit == other.downloadLimit &&
          uploadLimit == other.uploadLimit &&
          maxConnectionsPerTorrent == other.maxConnectionsPerTorrent &&
          maxGlobalConnections == other.maxGlobalConnections &&
          dhtEnabled == other.dhtEnabled &&
          pexEnabled == other.pexEnabled &&
          lsdEnabled == other.lsdEnabled &&
          wifiOnlyMode == other.wifiOnlyMode &&
          stopSeedingWhenFinished == other.stopSeedingWhenFinished &&
          defaultSavePath == other.defaultSavePath;

  @override
  int get hashCode => Object.hash(
    downloadLimit,
    uploadLimit,
    maxConnectionsPerTorrent,
    maxGlobalConnections,
    dhtEnabled,
    pexEnabled,
    lsdEnabled,
    wifiOnlyMode,
    stopSeedingWhenFinished,
    defaultSavePath,
  );
}
