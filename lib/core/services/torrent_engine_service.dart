import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../native/libtorrent_flutter_base.dart' as lt;
import '../native/models.dart' as lt;

import '../../domain/entities/torrent_status.dart' as domain;
import '../../domain/repositories/torrent_repository.dart';
import 'logger_service.dart';
import 'storage_service.dart';
import 'tracker_manager.dart';

/// Wraps LibtorrentFlutter and exposes a clean [Stream<List<domain.TorrentStatus>>].
///
/// Key responsibilities:
/// - Initialises the libtorrent session with [EngineConfig]
/// - Maps raw [lt.TorrentInfo] → domain [domain.TorrentStatus]
/// - Deduplicates emissions via deep field-by-field equality (Hardening #1)
/// - Throttles to ~500ms poll interval (set during init)
class TorrentEngineService {
  TorrentEngineService._();
  static final TorrentEngineService instance = TorrentEngineService._();

  bool _initialized = false;

  /// id → last emitted status snapshot
  Map<int, domain.TorrentStatus> _lastEmitted = {};

  /// id → magnet URI (for identity/deduplication)
  final Map<int, String> _idToMagnet = {};

  /// id → .torrent file path (for identity/deduplication)
  final Map<int, String> _idToFile = {};

  /// The raw address of the native libtorrent session (Hardening #5)
  int? get sessionAddress => _initialized ? _engine.session.address : null;

  /// The path where downloads are saved
  String? _defaultDownloadPath;
  String? get defaultDownloadPath => _defaultDownloadPath;

  /// Initialises the libtorrent session.
  /// Retries up to [maxRetries] times with exponential backoff. (Hardening #2)
  Future<void> initialize({
    EngineConfig config = const EngineConfig(),
    int maxRetries = 3,
  }) async {
    if (_initialized) return;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final customPath = prefs.getString('meitorrent_default_save_path');
        final defaultPath = (customPath != null && customPath.isNotEmpty)
            ? customPath
            : await StorageService.instance.getDownloadPath();

        final dir = Directory(defaultPath);
        if (!dir.existsSync()) {
          try {
            await dir.create(recursive: true);
          } catch (_) {}
        }

        _defaultDownloadPath = defaultPath;
        await lt.LibtorrentFlutter.init(
          pollInterval: const Duration(milliseconds: 200),
          fetchTrackers: true,
          downloadLimit: config.downloadLimit,
          uploadLimit: config.uploadLimit,
          defaultSavePath: defaultPath,
        );

        // Background fetch of best trackers for future magnets
        unawaited(TrackerManager.fetchBestTrackers());

        _initialized = true;
        AppLogger.i('[Engine] Initialized at $defaultPath (attempt $attempt)');
        return;
      } catch (e, st) {
        AppLogger.w(
          '[Engine] Init attempt $attempt failed',
          error: e,
          stack: st,
        );
        if (attempt == maxRetries) {
          AppLogger.e('[Engine] All $maxRetries attempts failed — giving up');
          rethrow;
        }
        final delay = Duration(seconds: 1 << (attempt - 1)); // 1s, 2s, 4s
        AppLogger.d('[Engine] Retrying in ${delay.inSeconds}s…');
        await Future<void>.delayed(delay);
      }
    }
  }

  bool get isInitialized => _initialized;

  lt.LibtorrentFlutter get _engine {
    assert(_initialized, 'TorrentEngineService not initialized');
    return lt.LibtorrentFlutter.instance;
  }

  // ─── Stream ──────────────────────────────────────────────────────

  /// Live stream of all torrent statuses, deduplicated (deep equality).
  Stream<List<domain.TorrentStatus>> get statusStream {
    assert(_initialized, 'TorrentEngineService not initialized');
    return _engine.torrentUpdates
        .map((map) => map.values.map(_toStatus).toList())
        .where(_hasChanged);
  }

  // Removed unsupported 'alerts' and 'saveResumeData' methods.

  // ─── Engine operations ────────────────────────────────────────────

  /// Adds a magnet link. Returns the integer torrent ID.
  int addMagnet(String uri, String savePath) {
    // Inject trackers for significantly better peer discovery (reference pattern)
    final enhancedUri = TrackerManager.injectTrackers(uri);
    final id = _engine.addMagnet(enhancedUri, savePath);
    _idToMagnet[id] = uri;
    return id;
  }

  /// Adds a magnet link with fast-resume data.
  int addMagnetWithResume(String uri, String savePath, Uint8List resumeData) {
    final enhancedUri = TrackerManager.injectTrackers(uri);
    final id = _engine.addMagnetWithResume(enhancedUri, savePath, resumeData);
    _idToMagnet[id] = uri;
    return id;
  }

  /// Adds a .torrent file. Returns the integer torrent ID.
  int addTorrentFile(String filePath, String savePath) {
    final id = _engine.addTorrentFile(filePath, savePath);
    _idToFile[id] = filePath;
    return id;
  }

  /// Adds a .torrent file with fast-resume data.
  int addTorrentFileWithResume(
    String filePath,
    String savePath,
    Uint8List resumeData,
  ) {
    final id = _engine.addTorrentFileWithResume(filePath, savePath, resumeData);
    _idToFile[id] = filePath;
    return id;
  }

  void pause(int id) => _engine.pauseTorrent(id);

  void resume(int id) => _engine.resumeTorrent(id);

  /// Gets the current engine-level status for a specific torrent ID.
  domain.TorrentStatus? getTorrentStatus(int id) {
    final raw = _engine.getStatus(id);
    if (raw == null) return null;
    return _toStatus(raw);
  }

  /// Gets the list of files for a specific torrent.
  List<lt.FileInfo> getFiles(int id) {
    return _engine.getFiles(id);
  }

  /// Sets download priorities per file (0 = skip, 1-7 = priority levels).
  void setFilePriorities(int id, List<int> priorities) {
    _engine.setFilePriorities(id, priorities);
  }

  void remove(int id, {bool deleteFiles = false}) {
    _engine.removeTorrent(id, deleteFiles: deleteFiles);
    _idToMagnet.remove(id);
    _idToFile.remove(id);
  }

  void forceRecheck(int id) {
    _engine.recheckTorrent(id);
    AppLogger.d('[Engine] forceRecheck issued for $id');
  }

  /// Returns the engine ID if a torrent with the given magnet URI is already registered.
  int? findIdByMagnet(String uri) {
    for (final entry in _idToMagnet.entries) {
      if (entry.value == uri) return entry.key;
    }
    return null;
  }

  /// Returns the engine ID if a torrent with the given file path is already registered.
  int? findIdByFile(String filePath) {
    for (final entry in _idToFile.entries) {
      if (entry.value == filePath) return entry.key;
    }
    return null;
  }

  /// Safely fetches fast-resume data for a torrent.
  Uint8List? getResumeDataSafe(int id) {
    if (!_initialized) return null;
    return _engine.getResumeDataSafe(id);
  }

  // Engine does not support explicit resume data saving or advanced params in this version.

  /// Apply speed limits via BtConfig
  void applyConfig(EngineConfig config) {
    if (!_initialized) return;
    _engine.setDownloadLimit(config.downloadLimit);
    _engine.setUploadLimit(config.uploadLimit);
    if (config.defaultSavePath != null && config.defaultSavePath!.isNotEmpty) {
      _defaultDownloadPath = config.defaultSavePath;
      AppLogger.i('[Engine] Updated default download path to: $_defaultDownloadPath');
    }
  }

  // ─── Deep equality deduplication (Hardening #1) ───────────────────

  bool _hasChanged(List<domain.TorrentStatus> next) {
    if (next.length != _lastEmitted.length) {
      _lastEmitted = {for (final s in next) _idForStatus(s): s};
      return true;
    }
    for (final s in next) {
      final old = _lastEmitted[_idForStatus(s)];
      if (old == null || !s.deepEquals(old)) {
        _lastEmitted = {for (final n in next) _idForStatus(n): n};
        return true;
      }
    }
    return false;
  }

  int _idForStatus(domain.TorrentStatus s) =>
      int.tryParse(s.id) ?? s.id.hashCode;

  // ─── Mapping ──────────────────────────────────────────────────────

  domain.TorrentStatus _toStatus(lt.TorrentInfo info) {
    final progress = info.progress.clamp(0.0, 1.0);
    final idInt = info.id;
    final isActuallyComplete = _isActuallyComplete(info, progress);

    return domain.TorrentStatus(
      id: idInt.toString(),
      name: info.name.isEmpty ? 'Torrent #$idInt' : info.name,
      progress: progress,
      downloadSpeed: info.downloadRate,
      uploadSpeed: info.uploadRate,
      peers: info.numPeers,
      seeds: info.numSeeds,
      state: _mapState(
        info.state,
        info.isPaused,
        info.isFinished,
        isActuallyComplete,
        hasMetadata: info.totalWanted > 0,
      ),
      totalSize: info.totalWanted,
      downloadedBytes: info.totalDone,
      uploadedBytes: info.totalUploaded,
      savePath: info.savePath.isEmpty
          ? (_defaultDownloadPath ?? '')
          : info.savePath,
      addedAt: _lastEmitted[idInt]?.addedAt ?? DateTime.now(),
      lastActivityAt: _lastEmitted[idInt]?.lastActivityAt ?? DateTime.now(),
      completedAt: _lastEmitted[idInt]?.completedAt,
      ratio: info.totalWanted > 0 ? info.totalUploaded / info.totalWanted : 0.0,
      etaSeconds: _computeEta(info),
      errorMessage: info.errorMsg.isEmpty ? null : info.errorMsg,
      isPaused: info.isPaused,
      isCompleted: isActuallyComplete,
      magnetUri: _idToMagnet[idInt],
      torrentFilePath: _idToFile[idInt],
    );
  }

  bool _isActuallyComplete(lt.TorrentInfo info, double progress) {
    if (info.totalWanted > 0 && info.totalDone >= info.totalWanted) {
      return true;
    }
    // Only trust the engine's finished flag if we have at least SOME data
    // to prevent transient/empty magnets from showing as finished.
    if (info.isFinished &&
        info.totalDone > 0 &&
        info.totalDone >= info.totalWanted) {
      return true;
    }
    return progress >= 1.0;
  }

  domain.TorrentState _mapState(
    lt.TorrentState raw,
    bool isPaused,
    bool isFinished,
    bool isActuallyComplete, {
    required bool hasMetadata,
  }) {
    // 1. Critical Verification: Hashing/Checking (Highest priority)
    if (raw == lt.TorrentState.checkingFiles ||
        raw == lt.TorrentState.checkingResume) {
      // Map both to checkingFiles for UI simplicity as requested
      return domain.TorrentState.checkingFiles;
    }

    // 2. Verified Completion: If we are 100% done, favor finished/seeding
    // This prevents "Allocating" or "Downloading" from flickering at 100%.
    if (isActuallyComplete) {
      if (!isPaused) {
        return domain.TorrentState.seeding;
      }
      return domain.TorrentState.finished;
    }

    // 3. Transient Allocation (Suppress for smoother UX)
    if (raw == lt.TorrentState.allocating) {
      return hasMetadata
          ? domain.TorrentState.downloading
          : domain.TorrentState.downloadingMetadata;
    }

    // 4. Active Downloading / Metadata fetching
    if (raw == lt.TorrentState.downloading ||
        raw == lt.TorrentState.downloadingMetadata) {
      if (isPaused) return domain.TorrentState.paused;
      return raw == lt.TorrentState.downloading
          ? domain.TorrentState.downloading
          : domain.TorrentState.downloadingMetadata;
    }

    // 5. Active Seeding (redundant but safe)
    if (raw == lt.TorrentState.seeding) {
      if (isPaused) return domain.TorrentState.finished;
      return domain.TorrentState.seeding;
    }

    // 6. Native Completed states (fallback if isActuallyComplete was somehow false)
    if (raw == lt.TorrentState.finished || isFinished) {
      if (isActuallyComplete) return domain.TorrentState.finished;

      // Handle premature completion
      AppLogger.w(
        '[Engine] Ignoring premature completion flag from engine '
        '(raw: $raw, hasMetadata: $hasMetadata, isFinished: $isFinished)',
      );
      return hasMetadata
          ? domain.TorrentState.downloading
          : domain.TorrentState.downloadingMetadata;
    }

    // 7. Paused (catch-all)
    if (isPaused) {
      return domain.TorrentState.paused;
    }

    // 8. Error fallback
    if (raw == lt.TorrentState.error) {
      return domain.TorrentState.error;
    }

    // 9. Final fallback for active torrents
    // Instead of showing UNKNOWN, show a metadata/downloading state based on data presence.
    return hasMetadata
        ? domain.TorrentState.downloading
        : domain.TorrentState.downloadingMetadata;
  }

  int? _computeEta(lt.TorrentInfo info) {
    if (info.downloadRate <= 0) return null;
    final remaining = info.totalWanted - info.totalDone;
    if (remaining <= 0) return 0;
    return (remaining / info.downloadRate).round();
  }
}
