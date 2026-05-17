// LibtorrentFlutter — Main engine class.
// Manages a libtorrent session with automatic tracker injection,
// status polling, and a built-in HTTP streaming server.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'dart:typed_data';

import 'ffi_bindings.dart';
import 'models.dart';

// ─── Tracker Management ─────────────────────────────────────────────────────

/// Automatically fetches and injects best public trackers into magnet URIs.
class TrackerManager {
  static final List<String> _extraTrackers = [];

  /// Fetch the latest best-performing tracker list from GitHub.
  static Future<void> fetchBestTrackers() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(
          'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(const SystemEncoding().decoder).join();
        final list = body
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        _extraTrackers.clear();
        _extraTrackers.addAll(list);
      }
      client.close(force: true);
    } catch (_) {}
  }

  /// Inject extra trackers into a magnet URI for better peer discovery.
  static String injectTrackers(String magnetUri) {
    if (_extraTrackers.isEmpty) return magnetUri;
    var uri = magnetUri;
    for (final tr in _extraTrackers) {
      if (!uri.contains(Uri.encodeComponent(tr))) {
        uri += '&tr=${Uri.encodeComponent(tr)}';
      }
    }
    return uri;
  }
}

// ─── Status converters ──────────────────────────────────────────────────────

TorrentInfo _toTorrentInfo(LtTorrentStatus s) => TorrentInfo(
      id: s.id,
      name: readCharArray(s.name, 512),
      savePath: readCharArray(s.savePath, 1024),
      errorMsg: readCharArray(s.errorMsg, 256),
      state: stateFromInt(s.state),
      progress: s.progress.clamp(0.0, 1.0),
      downloadRate: s.downloadRate,
      uploadRate: s.uploadRate,
      totalDone: s.totalDone,
      totalWanted: s.totalWanted,
      totalUploaded: s.totalUploaded,
      numPeers: s.numPeers,
      numSeeds: s.numSeeds,
      isPaused: s.isPaused != 0,
      isFinished: s.isFinished != 0,
      hasMetadata: s.hasMetadata != 0,
      queuePosition: s.queuePosition,
    );

FileInfo _toFileInfo(LtFileInfo f) => FileInfo(
      index: f.index,
      name: readCharArray(f.name, 512),
      path: readCharArray(f.path, 1024),
      size: f.size,
      isStreamable: f.isStreamable != 0,
    );

StreamInfo _toStreamInfo(LtStreamStatus s) => StreamInfo(
      id: s.id,
      torrentId: s.torrentId,
      fileIndex: s.fileIndex,
      url: readCharArray(s.url, 256),
      fileSize: s.fileSize,
      readHead: s.readHead,
      streamState: streamStateFromInt(s.streamState),
      bufferSeconds: s.bufferSeconds,
      bufferPieces: s.bufferPieces,
      readaheadWindow: s.readaheadWindow,
      activePeers: s.activePeers,
      downloadRate: s.downloadRate,
    );

// ─── LibtorrentFlutter ──────────────────────────────────────────────────────

/// The main libtorrent engine for Flutter.
///
/// Usage:
/// ```dart
/// await LibtorrentFlutter.init();
/// final torrentId = LibtorrentFlutter.instance.addMagnet(magnetUri, savePath);
/// final stream = LibtorrentFlutter.instance.startStream(torrentId);
/// // Pass stream.url to your video player
/// ```
class LibtorrentFlutter {
  static LibtorrentFlutter? _instance;
  static LibtorrentFlutter? get instanceInternal => _instance;

  late final TorrentBridgeBindings bindings;
  late final Pointer<LtSessionOpaque> session;
  late final String _defaultSavePath;

  // Torrent status
  final _torrentsCtrl = StreamController<Map<int, TorrentInfo>>.broadcast();
  final Map<int, TorrentInfo> _torrents = {};
  Timer? _pollTimer;

  // Stream status
  final _streamsCtrl = StreamController<Map<int, StreamInfo>>.broadcast();
  final Map<int, StreamInfo> _streams = {};

  static const _maxTorrents = 1024;
  static const _maxStreams = 64;

  LibtorrentFlutter._();

  /// The singleton instance. Only available after [init] completes.
  static LibtorrentFlutter get instance {
    if (_instance == null) {
      throw StateError('LibtorrentFlutter.init() not called');
    }
    return _instance!;
  }

  /// Whether the engine has been initialized.
  static bool get isInitialized => _instance != null;

  /// Initialize the libtorrent engine.
  ///
  /// - [listenInterface] — network interface to listen on (empty = all).
  /// - [downloadLimit] / [uploadLimit] — speed limits in bytes/sec (0 = unlimited).
  /// - [pollInterval] — how often to poll for torrent/stream status updates.
  /// - [fetchTrackers] — automatically fetch best public trackers on startup.
  /// - [defaultSavePath] — where to save torrent data. Defaults to system temp dir.
  static Future<void> init({
    String listenInterface = '',
    int downloadLimit = 0,
    int uploadLimit = 0,
    Duration pollInterval = const Duration(milliseconds: 600),
    bool fetchTrackers = true,
    String? defaultSavePath,
  }) async {
    if (_instance != null) return;
    final engine = LibtorrentFlutter._();

    // Fetch best trackers in background (fire & forget)
    if (fetchTrackers) {
      TrackerManager.fetchBestTrackers();
    }

    final lib = TorrentBridgeBindings.open();
    engine.bindings = lib;

    final iface = listenInterface.toNativeUtf8();
    try {
      final session =
          engine.bindings.createSession(iface, downloadLimit, uploadLimit);
      if (session == nullptr) {
        final err = engine.bindings.lastError().toDartString();
        throw StateError('Failed to create libtorrent session: $err');
      }
      engine.session = session;
    } finally {
      malloc.free(iface);
    }

    _instance = engine;
    engine._defaultSavePath = defaultSavePath ?? Directory.systemTemp.path;
    engine._startPolling(pollInterval);
  }

  /// Attach to an existing session from another isolate.
  static void attach({
    required int sessionAddress,
    String? defaultSavePath,
    Duration pollInterval = const Duration(milliseconds: 600),
  }) {
    if (_instance != null) return;
    final engine = LibtorrentFlutter._();
    engine.bindings = TorrentBridgeBindings.open();
    engine.session = Pointer<LtSessionOpaque>.fromAddress(sessionAddress);
    engine._defaultSavePath = defaultSavePath ?? Directory.systemTemp.path;
    _instance = engine;
    engine._startPolling(pollInterval);
  }

  // ─── Public Streams ─────────────────────────────────────────────────────────

  /// Stream of all torrent statuses, emitted on every poll update.
  Stream<Map<int, TorrentInfo>> get torrentUpdates => _torrentsCtrl.stream;

  /// Stream of all active stream statuses.
  Stream<Map<int, StreamInfo>> get streamUpdates => _streamsCtrl.stream;

  /// Current snapshot of all known torrents.
  Map<int, TorrentInfo> get torrents => Map.unmodifiable(_torrents);

  /// Current snapshot of all active streams.
  Map<int, StreamInfo> get streams => Map.unmodifiable(_streams);

  /// libtorrent version string.
  String get libraryVersion => bindings.version().toDartString();

  // ─── Torrent Management ─────────────────────────────────────────────────────

  /// Add a torrent from a magnet URI.
  ///
  /// Returns the torrent ID. [savePath] defaults to the path set in init().
  /// Set [streamOnly] to true to prevent background downloading.
  int addMagnet(String magnetUri, [String? savePath, bool streamOnly = false]) {
    final enhanced = TrackerManager.injectTrackers(magnetUri);
    final m = enhanced.toNativeUtf8();
    final s = (savePath ?? _defaultSavePath).toNativeUtf8();
    try {
      final id = bindings.addMagnet(session, m, s, streamOnly ? 1 : 0);
      if (id < 0) throw Exception(bindings.lastError().toDartString());
      return id;
    } finally {
      malloc.free(m);
      malloc.free(s);
    }
  }

  /// Add a torrent from a magnet URI with fast-resume data.
  int addMagnetWithResume(
      String magnetUri, String savePath, Uint8List resumeData) {
    final enhanced = TrackerManager.injectTrackers(magnetUri);
    final m = enhanced.toNativeUtf8();
    final s = savePath.toNativeUtf8();
    final resumePtr = malloc<Uint8>(resumeData.length);
    resumePtr.asTypedList(resumeData.length).setAll(0, resumeData);

    try {
      final binding = bindings.addMagnetWithResume;
      if (binding == null) {
        throw UnimplementedError('Native lt_add_magnet_with_resume not found');
      }

      final id = binding(session, m, s, resumePtr, resumeData.length);
      if (id < 0) throw Exception(bindings.lastError().toDartString());
      return id;
    } finally {
      malloc.free(m);
      malloc.free(s);
      malloc.free(resumePtr);
    }
  }

  /// Add a torrent from a .torrent file path.
  int addTorrentFile(String filePath,
      [String? savePath, bool streamOnly = false]) {
    final f = filePath.toNativeUtf8();
    final s = (savePath ?? _defaultSavePath).toNativeUtf8();
    try {
      final id = bindings.addTorrentFile(session, f, s, streamOnly ? 1 : 0);
      if (id < 0) throw Exception(bindings.lastError().toDartString());
      return id;
    } finally {
      malloc.free(f);
      malloc.free(s);
    }
  }

  /// Add a torrent from a .torrent file with fast-resume data.
  int addTorrentFileWithResume(
      String filePath, String savePath, Uint8List resumeData) {
    final f = filePath.toNativeUtf8();
    final s = savePath.toNativeUtf8();
    final resumePtr = malloc<Uint8>(resumeData.length);
    resumePtr.asTypedList(resumeData.length).setAll(0, resumeData);

    try {
      final binding = bindings.addTorrentFileWithResume;
      if (binding == null) {
        throw UnimplementedError(
            'Native lt_add_torrent_file_with_resume not found');
      }

      final id = binding(session, f, s, resumePtr, resumeData.length);
      if (id < 0) throw Exception(bindings.lastError().toDartString());
      return id;
    } finally {
      malloc.free(f);
      malloc.free(s);
      malloc.free(resumePtr);
    }
  }

  /// Remove a torrent. Optionally delete downloaded files.
  void removeTorrent(int id, {bool deleteFiles = false}) {
    bindings.removeTorrent(session, id, deleteFiles ? 1 : 0);
    _torrents.remove(id);
    _torrentsCtrl.add(Map.unmodifiable(_torrents));
  }

  /// Pause a torrent.
  void pauseTorrent(int id) => bindings.pauseTorrent(session, id);

  /// Resume a paused torrent.
  void resumeTorrent(int id) => bindings.resumeTorrent(session, id);

  /// Get the current status of a specific torrent.
  TorrentInfo? getStatus(int id) {
    final statusBuf = calloc<LtTorrentStatus>();
    try {
      final ok = bindings.getStatus(session, id, statusBuf);
      if (ok == 0) return null;
      return _toTorrentInfo(statusBuf.ref);
    } finally {
      calloc.free(statusBuf);
    }
  }

  /// Recheck torrent integrity.
  void recheckTorrent(int id) => bindings.recheckTorrent(session, id);

  /// Safely fetch fast-resume data for a torrent.
  /// Returns null if engine fails or data is too small to be valid.
  Uint8List? getResumeDataSafe(int id) {
    final getBinding = bindings.getResumeData;
    final freeBinding = bindings.freeResumeData;
    if (getBinding == null || freeBinding == null) return null;

    try {
      final res = getBinding(id);
      if (res.data == nullptr || res.size <= 100) {
        if (res.data != nullptr) freeBinding(res.data);
        return null;
      }

      final bytes = res.data.asTypedList(res.size);
      final copy = Uint8List.fromList(bytes);
      freeBinding(res.data);
      return copy;
    } catch (e) {
      // FFI calls might throw if symbols are missing or native crashes
      return null;
    }
  }

  // ─── File Enumeration ───────────────────────────────────────────────────────

  /// Get the list of files in a torrent (requires metadata).
  List<FileInfo> getFiles(int torrentId) {
    final count = bindings.getFileCount(session, torrentId);
    if (count <= 0) return [];
    final buf = calloc<LtFileInfo>(count);
    try {
      final n = bindings.getFiles(session, torrentId, buf, count);
      return List.generate(n, (i) => _toFileInfo(buf[i]));
    } finally {
      calloc.free(buf);
    }
  }

  /// Set download priorities per file (0 = skip, 1-7 = priority levels).
  void setFilePriorities(int torrentId, List<int> priorities) {
    final count = priorities.length;
    final buf = calloc<Int32>(count);
    try {
      for (var i = 0; i < count; i++) {
        buf[i] = priorities[i];
      }
      bindings.setFilePriorities(session, torrentId, buf, count);
    } finally {
      calloc.free(buf);
    }
  }

  // ─── Streaming ──────────────────────────────────────────────────────────────

  /// Start streaming a file from a torrent.
  ///
  /// Returns [StreamInfo] with an HTTP URL that can be passed to any video player.
  /// [fileIndex] = -1 auto-selects the largest streamable file.
  /// [maxCacheBytes] controls how much RAM the piece cache uses (0 = default ~128MB).
  StreamInfo startStream(int torrentId,
      {int fileIndex = -1, int maxCacheBytes = 0}) {
    final streamId =
        bindings.startStream(session, torrentId, fileIndex, maxCacheBytes);
    if (streamId < 0) {
      throw Exception(
          'startStream failed: ${bindings.lastError().toDartString()}');
    }
    final statusBuf = calloc<LtStreamStatus>();
    try {
      final ok = bindings.getStreamStatus(session, streamId, statusBuf);
      if (ok == 0) throw Exception('Failed to get stream status');
      final info = _toStreamInfo(statusBuf.ref);
      _streams[streamId] = info;
      _streamsCtrl.add(Map.unmodifiable(_streams));
      return info;
    } finally {
      calloc.free(statusBuf);
    }
  }

  /// Stop a stream.
  void stopStream(int streamId) {
    bindings.stopStream(session, streamId);
    _streams.remove(streamId);
    _streamsCtrl.add(Map.unmodifiable(_streams));
  }

  /// Stop all streams for a specific torrent.
  void stopAllStreamsForTorrent(int torrentId) {
    final toStop = _streams.entries
        .where((e) => e.value.torrentId == torrentId)
        .map((e) => e.key)
        .toList();
    for (final sid in toStop) {
      stopStream(sid);
    }
  }

  /// Get the current info for a specific stream, or null if not found.
  StreamInfo? getStreamInfo(int streamId) => _streams[streamId];

  /// Whether a torrent is currently being streamed.
  bool isStreaming(int torrentId) =>
      _streams.values.any((s) => s.torrentId == torrentId && s.isActive);

  /// Preload head + tail of the stream file for fast playback start.
  /// Port of TorrServer's torr/preload.go Preload() function.
  /// [preloadBytes] = 0 defaults to 16MB (head + tail).
  bool preloadStream(int streamId, {int preloadBytes = 0}) {
    return bindings.preloadStream(session, streamId, preloadBytes) != 0;
  }

  /// Configure the TorrServer-style cache for an active stream.
  /// Port of TorrServer's settings/btsets.go BTSets fields.
  ///
  /// - [capacity] — cache size in bytes (default 64MB).
  /// - [readAheadPct] — percentage 5-100 of cache used for read-ahead (default 95%).
  /// - [connectionsLimit] — max concurrent piece requests per reader (default 25).
  void setCacheSettings(
    int streamId, {
    int capacity = 0,
    int readAheadPct = 0,
    int connectionsLimit = 0,
  }) {
    bindings.setCacheSettings(
        session, streamId, capacity, readAheadPct, connectionsLimit);
  }

  // ─── Speed Limits ─────────────────────────────────────────────────────────

  /// Set download speed limit in bytes/sec (0 = unlimited).
  void setDownloadLimit(int bps) => bindings.setDownloadLimit(session, bps);

  /// Set upload speed limit in bytes/sec (0 = unlimited).
  void setUploadLimit(int bps) => bindings.setUploadLimit(session, bps);

  // ─── Engine Configuration — port of settings/btsets.go + btserver.go ───────

  /// Apply TorrServer-style engine configuration.
  ///
  /// Port of btserver.go configure(). Maps [BtConfig] fields to libtorrent
  /// settings_pack values: encryption, DHT, UPnP, rate limits, etc.
  /// Also applies cache/reader settings to all future streams.
  void configureSession(BtConfig config) {
    final cfgPtr = calloc<LtBtConfig>();
    try {
      cfgPtr.ref.cacheSize = config.cacheSize;
      cfgPtr.ref.readerReadAhead = config.readerReadAhead;
      cfgPtr.ref.preloadCache = config.preloadCache;
      cfgPtr.ref.connectionsLimit = config.connectionsLimit;
      cfgPtr.ref.torrentDisconnectTimeout = config.torrentDisconnectTimeout;
      cfgPtr.ref.forceEncrypt = config.forceEncrypt ? 1 : 0;
      cfgPtr.ref.disableTcp = config.disableTcp ? 1 : 0;
      cfgPtr.ref.disableUtp = config.disableUtp ? 1 : 0;
      cfgPtr.ref.disableUpload = config.disableUpload ? 1 : 0;
      cfgPtr.ref.disableDht = config.disableDht ? 1 : 0;
      cfgPtr.ref.disableUpnp = config.disableUpnp ? 1 : 0;
      cfgPtr.ref.enableIpv6 = config.enableIpv6 ? 1 : 0;
      cfgPtr.ref.downloadRateLimit = config.downloadRateLimit;
      cfgPtr.ref.uploadRateLimit = config.uploadRateLimit;
      cfgPtr.ref.peersListenPort = config.peersListenPort;
      cfgPtr.ref.responsiveMode = config.responsiveMode ? 1 : 0;
      bindings.configureSession(session, cfgPtr);
    } finally {
      calloc.free(cfgPtr);
    }
  }

  /// Get TorrServer's default engine configuration.
  ///
  /// Port of settings.SetDefaultConfig(). Returns a [BtConfig] with the
  /// same defaults TorrServer uses out of the box.
  BtConfig getDefaultConfig() {
    final cfgPtr = calloc<LtBtConfig>();
    try {
      bindings.getDefaultConfig(cfgPtr);
      return BtConfig(
        cacheSize: cfgPtr.ref.cacheSize,
        readerReadAhead: cfgPtr.ref.readerReadAhead,
        preloadCache: cfgPtr.ref.preloadCache,
        connectionsLimit: cfgPtr.ref.connectionsLimit,
        torrentDisconnectTimeout: cfgPtr.ref.torrentDisconnectTimeout,
        forceEncrypt: cfgPtr.ref.forceEncrypt != 0,
        disableTcp: cfgPtr.ref.disableTcp != 0,
        disableUtp: cfgPtr.ref.disableUtp != 0,
        disableUpload: cfgPtr.ref.disableUpload != 0,
        disableDht: cfgPtr.ref.disableDht != 0,
        disableUpnp: cfgPtr.ref.disableUpnp != 0,
        enableIpv6: cfgPtr.ref.enableIpv6 != 0,
        downloadRateLimit: cfgPtr.ref.downloadRateLimit,
        uploadRateLimit: cfgPtr.ref.uploadRateLimit,
        peersListenPort: cfgPtr.ref.peersListenPort,
        responsiveMode: cfgPtr.ref.responsiveMode != 0,
      );
    } finally {
      calloc.free(cfgPtr);
    }
  }

  /// Number of active streams across all torrents.
  int get activeStreamCount => bindings.getActiveStreams(session);

  // ─── Polling ──────────────────────────────────────────────────────────────

  void _startPolling(Duration interval) {
    _pollTimer = Timer.periodic(interval, (_) => _poll());
  }

  void _poll() {
    _pollTorrents();
    _pollStreams();
    _pollAlerts();
  }

  void _pollAlerts() {
    final callback =
        NativeCallable<LtAlertCallbackNative>.isolateLocal(_onAlert);
    try {
      bindings.pollAlerts(session, callback.nativeFunction, nullptr);
    } finally {
      callback.close();
    }
  }

  static void _onAlert(
      int type, int torrentId, Pointer<Utf8> message, Pointer<Void> userData) {
    // Silently consume alerts — users can listen to torrentUpdates for state changes.
    // Uncomment for debugging:
    // final msg = message.toDartString();
    // print('LibtorrentFlutter Alert: [T$torrentId] $msg');
  }

  void _pollTorrents() {
    final count = bindings.getTorrentCount(session);
    final buf = calloc<LtTorrentStatus>(max(count, _maxTorrents));
    try {
      final n = bindings.getAllStatuses(session, buf, max(count, _maxTorrents));
      bool changed = false;
      final seen = <int>{};

      for (var i = 0; i < n; i++) {
        final info = _toTorrentInfo(buf[i]);
        seen.add(info.id);
        final old = _torrents[info.id];
        if (old == null || _changed(old, info)) {
          _torrents[info.id] = info;
          changed = true;
        }
      }
      final stale = _torrents.keys.where((k) => !seen.contains(k)).toList();
      for (final k in stale) {
        _torrents.remove(k);
        changed = true;
      }
      if (changed) _torrentsCtrl.add(Map.unmodifiable(_torrents));
    } finally {
      calloc.free(buf);
    }
  }

  void _pollStreams() {
    if (_streams.isEmpty) return;
    final buf = calloc<LtStreamStatus>(_maxStreams);
    try {
      final n = bindings.getAllStreamStatuses(session, buf, _maxStreams);
      bool changed = false;
      for (var i = 0; i < n; i++) {
        final info = _toStreamInfo(buf[i]);
        final old = _streams[info.id];
        if (old == null ||
            old.streamState != info.streamState ||
            old.bufferPieces != info.bufferPieces ||
            old.readHead != info.readHead ||
            old.activePeers != info.activePeers) {
          _streams[info.id] = info;
          changed = true;
        }
        if (!info.isActive) {
          _streams.remove(info.id);
          changed = true;
        }
      }
      if (changed) _streamsCtrl.add(Map.unmodifiable(_streams));
    } finally {
      calloc.free(buf);
    }
  }

  bool _changed(TorrentInfo a, TorrentInfo b) =>
      a.state != b.state ||
      a.progress != b.progress ||
      a.downloadRate != b.downloadRate ||
      a.uploadRate != b.uploadRate ||
      a.totalDone != b.totalDone ||
      a.numPeers != b.numPeers ||
      a.isPaused != b.isPaused ||
      a.hasMetadata != b.hasMetadata ||
      a.name != b.name;

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  /// Clean up a single torrent: stops its streams, removes it, deletes files.
  ///
  /// Returns true if the torrent existed and was removed, false if it was
  /// already gone.
  bool disposeTorrent(int torrentId) {
    if (!_torrents.containsKey(torrentId)) return false;

    // Stop any active streams for this torrent
    stopAllStreamsForTorrent(torrentId);

    // Remove the torrent and delete its files
    removeTorrent(torrentId, deleteFiles: true);
    return true;
  }

  /// Clean up ALL torrents: stops every stream, removes every torrent,
  /// deletes all downloaded files. Call this on your exit button.
  void disposeAll() {
    // Stop all streams first
    for (final sid in _streams.keys.toList()) {
      try {
        stopStream(sid);
      } catch (_) {}
    }

    // Remove all torrents and delete their files
    for (final tid in _torrents.keys.toList()) {
      try {
        removeTorrent(tid, deleteFiles: true);
      } catch (_) {}
    }
  }

  /// Shut down the engine entirely. Calls [disposeAll] first, then
  /// destroys the native session. After this, you'd need to call
  /// [init] again to use the engine.
  Future<void> dispose() async {
    disposeAll();
    _pollTimer?.cancel();
    bindings.destroySession(session);
    await _torrentsCtrl.close();
    await _streamsCtrl.close();
    _instance = null;
  }
}
