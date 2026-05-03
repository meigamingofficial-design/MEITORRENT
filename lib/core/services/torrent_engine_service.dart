import 'dart:async';

import 'package:libtorrent_flutter/libtorrent_flutter.dart' as lt
    show LibtorrentFlutter, TorrentInfo, TorrentState;

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

  /// Initialises the libtorrent session.
  /// Retries up to [maxRetries] times with exponential backoff. (Hardening #2)
  Future<void> initialize({
    EngineConfig config = const EngineConfig(),
    int maxRetries = 3,
  }) async {
    if (_initialized) return;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await StorageService.instance.ensureDirectoryExists();
        final defaultPath = await StorageService.instance.getDownloadPath();
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
        AppLogger.w('[Engine] Init attempt $attempt failed',
            error: e, stack: st);
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
    return _engine.addMagnet(enhancedUri, savePath);
  }

  /// Adds a .torrent file. Returns the integer torrent ID.
  int addTorrentFile(String filePath, String savePath) {
    return _engine.addTorrentFile(filePath, savePath);
  }

  void pause(int id) => _engine.pauseTorrent(id);

  void resume(int id) => _engine.resumeTorrent(id);

  void remove(int id, {bool deleteFiles = false}) =>
      _engine.removeTorrent(id, deleteFiles: deleteFiles);

  void forceRecheck(int id) {
    _engine.recheckTorrent(id);
    AppLogger.d('[Engine] forceRecheck issued for $id');
  }

  // Engine does not support explicit resume data saving or advanced params in this version.

  /// Apply speed limits via BtConfig
  void applyConfig(EngineConfig config) {
    _engine.setDownloadLimit(config.downloadLimit);
    _engine.setUploadLimit(config.uploadLimit);
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
      savePath: info.savePath,
      addedAt: _lastEmitted[idInt]?.addedAt ?? DateTime.now(),
      ratio: info.totalWanted > 0 ? info.totalUploaded / info.totalWanted : 0.0,
      etaSeconds: _computeEta(info),
      errorMessage: info.errorMsg.isEmpty ? null : info.errorMsg,
      isPaused: info.isPaused,
      isCompleted: isActuallyComplete || info.state == lt.TorrentState.seeding,
    );
  }

  bool _isActuallyComplete(lt.TorrentInfo info, double progress) {
    if (progress >= 0.999) {
      return true;
    }
    return info.totalWanted > 0 && info.totalDone >= info.totalWanted;
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
      if (isPaused) return domain.TorrentState.paused;
      if (raw == lt.TorrentState.seeding) return domain.TorrentState.seeding;
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
      if (isPaused) return domain.TorrentState.paused;
      return domain.TorrentState.seeding;
    }

    // 6. Native Completed states (fallback if isActuallyComplete was somehow false)
    if (raw == lt.TorrentState.finished || isFinished) {
      // Respect paused state even if engine reports finished
      if (isPaused) return domain.TorrentState.paused;

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
