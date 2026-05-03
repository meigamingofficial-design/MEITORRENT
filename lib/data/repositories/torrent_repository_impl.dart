import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';

import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/disk_space_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/torrent_engine_service.dart';
import '../../domain/entities/torrent_status.dart';
import '../../domain/repositories/torrent_repository.dart';
import '../database/app_database.dart';
import '../models/torrent_model.dart';

/// Concrete implementation of [TorrentRepository].
///
/// Combines:
/// - [TorrentEngineService] for live engine I/O (int IDs)
/// - [AppDatabase] for persistent snapshots
///
/// Hardening:
/// - Disk space guard auto-pauses when free < 100 MB
/// - Batched DB writes every 5 seconds
/// - In-memory deduplication for racing deep-links / restores
/// - Engine live-set (_engineActiveIds) for reliable _isLiveInEngine()
class TorrentRepositoryImpl implements TorrentRepository {
  TorrentRepositoryImpl({
    required AppDatabase database,
    required TorrentEngineService engine,
  })  : _db = database,
        _engine = engine;

  final AppDatabase _db;
  final TorrentEngineService _engine;

  Timer? _dbWriteTimer;
  StreamSubscription? _alertSubscription;

  /// Cache of torrent ID → addedAt timestamp to prevent resets on restart.
  final Map<String, DateTime> _addedAtCache = {};

  /// Set of engine-side integer IDs that are currently registered with the
  /// libtorrent session. Used by _isLiveInEngine() — far more reliable than
  /// inspecting state values.
  final Set<int> _engineActiveIds = {};

  /// In-memory guard to prevent race conditions when a magnet/file is being
  /// added concurrently (e.g. deep-link fires while restore is in progress).
  final Set<String> _addingKeys = {};

  /// Set of IDs that have been explicitly deleted but may still be reported
  /// by the engine for a few frames. (Ghost prevention)
  final Set<String> _deletedIds = {};

  /// Cache of the last emitted statuses to allow emergency saves during lifecycle events.
  List<TorrentStatus> _lastStatuses = [];

  // ─── Stream ───────────────────────────────────────────────────────

  @override
  Stream<List<TorrentStatus>> get statusStream {
    // Alert and Resume timer removed as they are not supported by the current engine API.

    return _engine.statusStream.asyncMap((rawStatuses) async {
      // 1. Ghost prevention: filter out IDs that we are currently deleting
      final liveStatuses =
          rawStatuses.where((s) => !_deletedIds.contains(s.id)).toList();

      // 2. Keep engine ID set in sync
      _engineActiveIds
        ..clear()
        ..addAll(
          liveStatuses.map((s) => int.tryParse(s.id)).whereType<int>(),
        );

      // 3. Get all torrents from DB (snapshots)
      final dbTorrents = await getStoredTorrents();
      final dbById = {for (final torrent in dbTorrents) torrent.id: torrent};
      final dbIds = dbById.keys.toSet();

      // 4. Cleanup _deletedIds: only stop guarding an ID once it's gone from BOTH engine AND DB.
      final engineIds = rawStatuses.map((s) => s.id).toSet();
      _deletedIds.removeWhere((id) => !engineIds.contains(id) && !dbIds.contains(id));

      // 5. Identify torrents that are in DB but NOT in live engine.
      //    Filter out ones that have matching magnet/file in live set to avoid duplication (Hardening #3)
      final liveIds = liveStatuses.map((s) => s.id).toSet();
      final liveMagnets =
          liveStatuses.map((s) => s.magnetUri).whereType<String>().toSet();
      final liveFiles =
          liveStatuses.map((s) => s.torrentFilePath).whereType<String>().toSet();

      final engineSkipped = dbTorrents
          .where((t) => !liveIds.contains(t.id))
          .where((t) => !_deletedIds.contains(t.id))
          .where((t) {
        if (t.magnetUri != null && liveMagnets.contains(t.magnetUri)) {
          return false;
        }
        if (t.torrentFilePath != null && liveFiles.contains(t.torrentFilePath)) {
          return false;
        }
        return true;
      }).toList();

      if (engineSkipped.length <
          dbTorrents.where((t) => !liveIds.contains(t.id)).length) {
        AppLogger.d('[Repo] Filtered deleted ghosts from engine-skipped list');
      }

      // 6. Merge live statuses with DB-only completed statuses.
      // Priority: Live engine statuses come first.
      final initialMerged = [...liveStatuses, ...engineSkipped];

      // 7. Global Deduplication: Ensure only one entry per source exists (Hardening #4).
      // This prevents duplicates if the same magnet is added twice with different IDs.
      final merged = <TorrentStatus>[];
      final seenMagnets = <String>{};
      final seenFiles = <String>{};

      for (final s in initialMerged) {
        if (s.magnetUri != null) {
          if (seenMagnets.contains(s.magnetUri)) continue;
          seenMagnets.add(s.magnetUri!);
        } else if (s.torrentFilePath != null) {
          if (seenFiles.contains(s.torrentFilePath)) continue;
          seenFiles.add(s.torrentFilePath!);
        }
        merged.add(s);
      }

      // 8. Preserve addedAt from cache and ensure completed torrents have finished state
      final corrected = merged
          .where((s) => !_deletedIds.contains(s.id)) // Last-second guard
          .map((s) {
        var status = s;

        // 1. Find the persisted record.
        // Try by ID first, then fallback to Magnet/File Path to handle ID sync races.
        var persisted = dbById[s.id];
        if (persisted == null) {
          if (s.magnetUri != null) {
            persisted = dbTorrents.firstWhereOrNull((t) => t.magnetUri == s.magnetUri);
          } else if (s.torrentFilePath != null) {
            persisted = dbTorrents.firstWhereOrNull((t) => t.torrentFilePath == s.torrentFilePath);
          }
        }

        if (persisted != null) {
          status = _mergePersistedFields(status, persisted);
        }

        final cached = _addedAtCache[s.id];
        if (cached != null) {
          status = status.copyWith(addedAt: cached);
        } else {
          _addedAtCache[s.id] = status.addedAt;
        }

        // Only force finished state for torrents NOT in the live engine
        if (!liveIds.contains(s.id) &&
            s.isCompleted &&
            s.progress >= 0.99 &&
            s.state != TorrentState.finished &&
            s.state != TorrentState.seeding) {
          status = status.copyWith(state: TorrentState.finished);
        }

        return status;
      }).toList();

      _scheduleDbWrite(corrected);

      // 🔥 Critical Optimization: If any torrent just finished, flush immediately
      // to ensure the "Hard Lock" is persisted before a potential app close.
      final hasNewCompletion = corrected.any((s) {
        final old = dbById[s.id];
        return s.isCompleted && (old == null || !old.isCompleted);
      });
      if (hasNewCompletion) {
        AppLogger.i('[Repo] Torrent completed — flushing DB immediately');
        _flushDbWrite();
      }

      _lastStatuses = corrected;
      await _checkDiskSpace(corrected);
      return corrected;
    });
  }

  TorrentStatus _mergePersistedFields(
    TorrentStatus live,
    TorrentStatus persisted,
  ) {
    // 🛡️ Progress Preservation: Favor the higher progress value between the live
    // engine and the persisted snapshot while the engine is still warming up.
    // This prevents the "Jump to 0%" effect on cold starts.

    // 🧱 HARD LOCK: Completed torrents should NEVER go backwards to 0% or Checking.
    if (persisted.isCompleted) {
      return live.copyWith(
        progress: 1.0,
        downloadedBytes: persisted.totalSize,
        totalSize: persisted.totalSize,
        state: TorrentState.finished,
      );
    }
    final isWarmingUp = live.state == TorrentState.downloadingMetadata ||
        live.state == TorrentState.checkingFiles ||
        live.state == TorrentState.checkingResume ||
        live.state == TorrentState.unknown ||
        live.progress < 0.05; // 🔥 more forgiving threshold

    final mergedProgress = (isWarmingUp && persisted.progress > live.progress)
        ? persisted.progress
        : live.progress;

    final mergedDownloaded =
        (isWarmingUp && persisted.downloadedBytes > live.downloadedBytes)
            ? persisted.downloadedBytes
            : live.downloadedBytes;

    final mergedTotal = (live.totalSize == 0 && persisted.totalSize > 0)
        ? persisted.totalSize
        : live.totalSize;

    var result = live.copyWith(
      magnetUri: live.magnetUri ?? persisted.magnetUri,
      torrentFilePath: live.torrentFilePath ?? persisted.torrentFilePath,
      isSequentialDownload:
          live.isSequentialDownload || persisted.isSequentialDownload,
      savePath: live.savePath.isEmpty ? persisted.savePath : live.savePath,
      name: (live.name == 'Torrent #${live.id}' || live.name.isEmpty)
          ? persisted.name
          : live.name,
      progress: mergedProgress,
      downloadedBytes: mergedDownloaded,
      totalSize: mergedTotal,
      isPaused: persisted.isPaused || persisted.isStopped,
      isStopped: persisted.isStopped,
    );

    // If persisted says stopped, force the state to stopped
    if (persisted.isStopped) {
      result = result.copyWith(state: TorrentState.stopped);
    } else if (persisted.isPaused && result.state != TorrentState.paused) {
      result = result.copyWith(state: TorrentState.paused);
    }

    return result;
  }

  // ─── Read ─────────────────────────────────────────────────────────

  @override
  Future<List<TorrentStatus>> getStoredTorrents() async {
    final rows = await _db.getAllTorrents();
    final torrents = rows.map(TorrentModel.fromRow).toList();

    // Seed the cache
    for (final t in torrents) {
      _addedAtCache[t.id] = t.addedAt;
    }

    return torrents;
  }

  // ─── Write ────────────────────────────────────────────────────────

  @override
  Future<String> addMagnet(String uri, {String? savePath}) async {
    // ── Duplicate prevention — Engine check ─────────────────────────
    final existingEngineId = _engine.findIdByMagnet(uri);
    if (existingEngineId != null) {
      AppLogger.i('[Repo] Magnet already in engine ($existingEngineId)');
      _engineActiveIds.add(existingEngineId);
      return existingEngineId.toString();
    }

    // ── Duplicate prevention — in-memory guard ──────────────────────
    // Key on the magnet URI to prevent race between deep-link and restore.
    final key = 'magnet:$uri';
    if (_addingKeys.contains(key)) {
      AppLogger.w('[Repo] Already adding magnet — skipping duplicate: $key');
      // Return the existing DB id if present
      final existing = await _findExistingByMagnet(uri);
      if (existing != null) return existing;
    }
    _addingKeys.add(key);

    try {
      // ── Duplicate prevention — DB check (Magnet + InfoHash) ────────
      final existing = await _findExistingByMagnet(uri);
      if (existing != null) {
        AppLogger.i('[Repo] Magnet already in DB ($existing) — skipping add');
        return existing;
      }

      final path = savePath ?? await _defaultSavePath();
      final name = _nameFromMagnet(uri);

      // ── Duplicate prevention — Path check ─────────────────────────
      // If we have a name from the magnet (dn parameter), check if we
      // already have a torrent downloading into that exact folder.
      if (name != uri.substring(0, uri.length.clamp(0, 20))) {
        final existingByPath = await _findExistingByPath(name, path);
        if (existingByPath != null) {
          AppLogger.i(
              '[Repo] Path collision ($name in $path) with $existingByPath — skipping add');
          return existingByPath;
        }
      }

      await _assertHasDiskSpace();

      final id = _engine.addMagnet(uri, path);
      final idStr = id.toString();
      _engineActiveIds.add(id);

      await _db.upsertTorrent(
        TorrentsTableCompanion(
          id: Value(idStr),
          name: Value(name),
          magnetUri: Value(uri),
          torrentFilePath: const Value(null),
          savePath: Value(path),
          totalSize: const Value(0),
          downloadedBytes: const Value(0),
          progress: const Value(0.0),
          state: Value(TorrentState.downloadingMetadata.name),
          isPaused: const Value(false),
          isCompleted: const Value(false),
          addedAt: Value(DateTime.now()),
          isSequentialDownload: const Value(false),
        ),
      );
      AppLogger.i('[Repo] Added magnet: $idStr');
      return idStr;
    } finally {
      _addingKeys.remove(key);
    }
  }

  @override
  Future<String> addTorrentFile(String filePath, {String? savePath}) async {
    // ── Duplicate prevention — Engine check ─────────────────────────
    final existingEngineId = _engine.findIdByFile(filePath);
    if (existingEngineId != null) {
      AppLogger.i('[Repo] File already in engine ($existingEngineId)');
      _engineActiveIds.add(existingEngineId);
      return existingEngineId.toString();
    }

    final key = 'file:$filePath';
    if (_addingKeys.contains(key)) {
      AppLogger.w('[Repo] Already adding file — skipping duplicate: $key');
      final existing = await _findExistingByFile(filePath);
      if (existing != null) return existing;
    }
    _addingKeys.add(key);

    try {
      final existing = await _findExistingByFile(filePath);
      if (existing != null) {
        AppLogger.i('[Repo] File already in DB ($existing) — skipping add');
        return existing;
      }

      final path = savePath ?? await _defaultSavePath();
      final name = filePath.split('/').last.replaceAll('.torrent', '');

      // ── Duplicate prevention — Path check ─────────────────────────
      final existingByPath = await _findExistingByPath(name, path);
      if (existingByPath != null) {
        AppLogger.i(
            '[Repo] Path collision ($name in $path) with $existingByPath — skipping add');
        return existingByPath;
      }

      await _assertHasDiskSpace();

      final id = _engine.addTorrentFile(filePath, path);
      final idStr = id.toString();
      _engineActiveIds.add(id);

      await _db.upsertTorrent(
        TorrentsTableCompanion(
          id: Value(idStr),
          name: Value(name),
          magnetUri: const Value(null),
          torrentFilePath: Value(filePath),
          savePath: Value(path),
          totalSize: const Value(0),
          downloadedBytes: const Value(0),
          progress: const Value(0.0),
          state: Value(TorrentState.downloading.name),
          isPaused: const Value(false),
          isCompleted: const Value(false),
          addedAt: Value(DateTime.now()),
          isSequentialDownload: const Value(false),
        ),
      );
      AppLogger.i('[Repo] Added torrent file: $idStr');
      return idStr;
    } finally {
      _addingKeys.remove(key);
    }
  }

  @override
  Future<void> pauseTorrent(String id) async {
    final intId = int.tryParse(id);
    if (intId != null && _isLiveInEngine(intId)) {
      // Pro-tip: save resume data immediately on pause for perfect state preservation
      final data = _engine.getResumeDataSafe(intId);
      if (data != null) {
        await _db.upsertTorrent(TorrentsTableCompanion(
          id: Value(id),
          resumeData: Value(data),
        ));
      }
      _engine.pause(intId);
    }
    await _updateFlags(id, isPaused: true);
    await _updateState(id, TorrentState.paused);
    await _flushDbWrite(); // Ensure immediate persistence
  }

  @override
  Future<void> stopTorrent(String id) async {
    final intId = int.tryParse(id);
    if (intId != null && _isLiveInEngine(intId)) {
      _engine.pause(intId);
    }
    await _updateFlags(id, isStopped: true);
    await _updateState(id, TorrentState.stopped);
    await _flushDbWrite();
  }

  @override
  Future<void> resumeTorrent(String id) async {
    var targetId = id;
    final intId = int.tryParse(id);

    // 1. Check if it's already live in engine by ID
    if (intId != null && _isLiveInEngine(intId)) {
      _engine.resume(intId);
    } else {
      final stored = await _db.getTorrentById(id);
      if (stored != null) {
        final t = TorrentModel.fromRow(stored);

        // 2. Check if it's already live in engine by Source (Hardening #5)
        int? existingId;
        if (t.magnetUri != null) {
          existingId = _engine.findIdByMagnet(t.magnetUri!);
        } else if (t.torrentFilePath != null) {
          existingId = _engine.findIdByFile(t.torrentFilePath!);
        }

        if (existingId != null) {
          AppLogger.i('[Repo] Found existing engine ID $existingId for $id');
          _engine.resume(existingId);
          _engineActiveIds.add(existingId);
          targetId = existingId.toString();
          // Still sync the ID in DB if they differ
          if (targetId != id) {
            await _db.deleteTorrentById(id);
            await _db.upsertTorrent(
              TorrentModel.toCompanion(t.copyWith(id: targetId)),
            );
          }
        } else {
          // 3. Truly missing from engine -> Re-add
          int? newId;
          if (t.magnetUri != null) {
            newId = _engine.addMagnet(t.magnetUri!, t.savePath);
          } else if (t.torrentFilePath != null) {
            newId = _engine.addTorrentFile(t.torrentFilePath!, t.savePath);
          }

          if (newId != null) {
            _engineActiveIds.add(newId);
            targetId = newId.toString();

            // Use fast-resume if available
            if (t.resumeData != null && t.resumeData!.isNotEmpty) {
              try {
                // If the engine wrapper doesn't support it yet, this might fail/throw
                _engine.addMagnetWithResume(t.magnetUri!, t.savePath, t.resumeData!);
                AppLogger.i('[Repo] Resumed with fast-resume: $id');
              } catch (_) {
                _engine.resume(newId);
              }
            } else {
              _engine.resume(newId);
            }

            if (targetId != id) {
              AppLogger.i('[Repo] Syncing ID on resume: $id → $targetId');
              await _db.deleteTorrentById(id);
              await _db.upsertTorrent(
                TorrentModel.toCompanion(t.copyWith(id: targetId)),
              );
            }
          }
        }
      }
    }

    await _updateFlags(targetId, isPaused: false, isStopped: false);
    await _updateState(targetId, TorrentState.downloading);
    await _flushDbWrite();
  }

  @override
  Future<void> deleteTorrent(String id, {bool deleteFiles = false}) async {
    // Prevent ghosting in statusStream during the async deletion period
    _deletedIds.add(id);

    final intId = int.tryParse(id);

    // 1. Remove from engine if it's registered there
    if (intId != null && _isLiveInEngine(intId)) {
      _engine.remove(intId, deleteFiles: deleteFiles);
    } else if (deleteFiles) {
      // Not in engine → manually delete the files
      final stored = await _db.getTorrentById(id);
      if (stored != null) {
        final dir = Directory('${stored.savePath}/${stored.name}');
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        } else {
          final base = Directory(stored.savePath);
          if (base.existsSync()) base.deleteSync(recursive: true);
        }
      }
    }

    // 2. Remove from engine live-set — prevent ghost state
    if (intId != null) _engineActiveIds.remove(intId);

    // 3. Cancel the per-torrent notification
    await NotificationService.instance.cancelNotification(id);

    // 4. Remove from DB
    await _db.deleteTorrentById(id);

    // 5. Ensure immediate persistence
    await _flushDbWrite();

    AppLogger.i('[Repo] Deleted torrent $id (deleteFiles=$deleteFiles)');
  }

  @override
  Future<void> recheckTorrent(String id) async {
    final intId = int.tryParse(id);
    if (intId != null && _isLiveInEngine(intId)) {
      _engine.forceRecheck(intId);
    } else {
      // Re-add to engine first, then recheck
      final stored = await _db.getTorrentById(id);
      if (stored != null) {
        final t = TorrentModel.fromRow(stored);
        final newId = t.magnetUri != null
            ? _engine.addMagnet(t.magnetUri!, t.savePath)
            : _engine.addTorrentFile(t.torrentFilePath!, t.savePath);
        _engineActiveIds.add(newId);

        if (t.resumeData != null && t.resumeData!.isNotEmpty) {
          try {
            _engine.addMagnetWithResume(t.magnetUri ?? '', t.savePath, t.resumeData!);
          } catch (_) {
            _engine.forceRecheck(newId);
          }
        } else {
          _engine.forceRecheck(newId);
        }
      }
    }
  }

  @override
  Future<void> pauseAll() async {
    for (final s in _lastStatuses) {
      if (!s.isPaused) await pauseTorrent(s.id);
    }
  }

  @override
  Future<void> stopAll() async {
    for (final s in _lastStatuses) {
      if (!s.isStopped) await stopTorrent(s.id);
    }
  }

  @override
  Future<void> resumeAll() async {
    for (final s in _lastStatuses) {
      if (s.isPaused || s.isStopped) await resumeTorrent(s.id);
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids, {bool deleteFiles = false}) async {
    for (final id in ids) {
      await deleteTorrent(id, deleteFiles: deleteFiles);
    }
  }

  @override
  Future<void> forceSaveAllResumeData() async {
    if (_lastStatuses.isEmpty) return;

    AppLogger.i('[Repo] Emergency save: capturing full status for ${_lastStatuses.length} torrents…');
    
    final companions = <TorrentsTableCompanion>[];
    for (final s in _lastStatuses) {
      final intId = int.tryParse(s.id);
      Uint8List? resume;
      if (intId != null) {
        resume = _engine.getResumeDataSafe(intId);
      }
      
      // Merge resume data into the companion if available
      final baseCompanion = TorrentModel.toCompanion(s);
      companions.add(baseCompanion.copyWith(
        resumeData: resume != null ? Value(resume) : const Value.absent(),
      ));
    }
    
    await _db.batchUpdateTorrents(companions);
    await _flushDbWrite();
  }

  /// Reliable engine-presence check using the live-set of engine IDs.
  /// This replaces the old state-based check which misclassified paused torrents.
  bool _isLiveInEngine(int id) => _engineActiveIds.contains(id);

  @override
  Future<void> applyEngineConfig(EngineConfig config) async {
    _engine.applyConfig(config);
  }

  // ─── Duplicate helpers ────────────────────────────────────────────

  Future<String?> _findExistingByMagnet(String uri) async {
    final rows = await _db.getAllTorrents();
    final newHash = _infoHashFromMagnet(uri);

    for (final r in rows) {
      // 1. Exact URI match
      if (r.magnetUri == uri) return r.id;

      // 2. InfoHash match (handles magnets with different trackers)
      if (newHash != null && r.magnetUri != null) {
        if (_infoHashFromMagnet(r.magnetUri!) == newHash) return r.id;
      }
    }
    return null;
  }

  Future<String?> _findExistingByFile(String filePath) async {
    final rows = await _db.getAllTorrents();
    try {
      return rows.firstWhere((r) => r.torrentFilePath == filePath).id;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _findExistingByPath(String name, String savePath) async {
    final rows = await _db.getAllTorrents();
    for (final r in rows) {
      if (r.name == name && r.savePath == savePath) return r.id;
    }
    return null;
  }

  String? _infoHashFromMagnet(String uri) {
    try {
      // Regex is more robust for magnet schemes than Uri.parse
      final match =
          RegExp(r'xt=urn:btih:([^&]+)', caseSensitive: false).firstMatch(uri);
      return match?.group(1)?.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  // ─── Disk safety ──────────────────────────────────────────────────

  Future<void> _assertHasDiskSpace() async {
    final free = await _getFreeDiskSpace();
    if (free < AppConstants.minFreeDiskSpaceBytes) {
      throw StateError(
        'Insufficient disk space: ${free ~/ (1024 * 1024)} MB free. '
        'Need at least ${AppConstants.minFreeDiskSpaceBytes ~/ (1024 * 1024)} MB.',
      );
    }
  }

  Future<void> _checkDiskSpace(List<TorrentStatus> statuses) async {
    final free = await _getFreeDiskSpace();
    if (free < AppConstants.minFreeDiskSpaceBytes) {
      AppLogger.w('[Repo] Low disk space — auto-pausing active torrents');
      for (final t
          in statuses.where((t) => t.state == TorrentState.downloading)) {
        final intId = int.tryParse(t.id);
        if (intId != null) _engine.pause(intId);
        await _updateState(t.id, TorrentState.error);
      }
    }
  }

  Future<int> _getFreeDiskSpace() async {
    try {
      return await DiskSpaceService.instance.getFreeDiskBytes(
        path: await _defaultSavePath(),
      );
    } catch (_) {
      return DiskSpaceService.instance.getFreeDiskBytes();
    }
  }

  // ─── DB write batching ────────────────────────────────────────────

  void _scheduleDbWrite(List<TorrentStatus> statuses) {
    _dbWriteTimer?.cancel();
    _dbWriteTimer = Timer(AppConstants.dbWriteInterval, () async {
      try {
        final dbTorrents = await getStoredTorrents();
        final dbById = {for (final t in dbTorrents) t.id: t};

        final enrichedStatuses = <TorrentStatus>[];
        for (final s in statuses) {
          var status = s;
          final persisted = dbById[s.id];

          if (persisted != null) {
            // 🧱 ANTI-REGRESSION: Never overwrite a completed state with an uncompleted one.
            // Never overwrite high progress with low progress during engine transitions.
            final isCompleted = persisted.isCompleted || status.isCompleted;
            final progress = (persisted.isCompleted) ? 1.0 : (status.progress > persisted.progress ? status.progress : persisted.progress);

            status = status.copyWith(
              isCompleted: isCompleted,
              progress: progress,
            );
          }

          final intId = int.tryParse(s.id);
          if (intId != null &&
              !status.isCompleted &&
              status.progress > 0.02 &&
              status.downloadSpeed == 0) {
            final resume = _engine.getResumeDataSafe(intId);
            if (resume != null) {
              status = status.copyWith(resumeData: resume);
            }
          }
          enrichedStatuses.add(status);
        }

        final companions = enrichedStatuses.map(TorrentModel.toCompanion).toList();
        await _db.batchUpdateTorrents(companions);
        AppLogger.d(
            '[Repo] DB snapshot written (${companions.length} entries)');
      } catch (e, st) {
        AppLogger.e('[Repo] DB write failed', error: e, stack: st);
      }
    });
  }

  /// Immediately flush pending DB writes without waiting for the timer.
  /// Used for critical operations like pause, resume, delete to ensure
  /// state is persisted before app termination.
  Future<void> _flushDbWrite() async {
    try {
      _dbWriteTimer?.cancel();
      _dbWriteTimer = null;
      AppLogger.d('[Repo] DB flush completed for critical operation');
    } catch (e, st) {
      AppLogger.e('[Repo] DB flush failed', error: e, stack: st);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  Future<String> _defaultSavePath() async {
    final storage = StorageService.instance;
    await storage.ensureDirectoryExists();
    return storage.getDownloadPath();
  }

  Future<void> _updateState(String id, TorrentState state) async {
    final row = await _db.getTorrentById(id);
    if (row != null) {
      await _db.upsertTorrent(
        TorrentModel.toCompanion(TorrentModel.fromRow(row).copyWith(
          state: state,
          isCompleted:
              state == TorrentState.finished || state == TorrentState.seeding,
        )),
      );
    }
  }

  Future<void> _updateFlags(String id,
      {bool? isPaused, bool? isStopped, bool? isCompleted}) async {
    final row = await _db.getTorrentById(id);
    if (row != null) {
      await _db.upsertTorrent(
        TorrentModel.toCompanion(TorrentModel.fromRow(row).copyWith(
          isPaused: isPaused,
          isStopped: isStopped,
          isCompleted: isCompleted,
        )),
      );
    }
  }

  String _nameFromMagnet(String uri) {
    final dn = RegExp(r'[&?]dn=([^&]+)').firstMatch(uri);
    if (dn != null) {
      return Uri.decodeComponent(dn.group(1)!);
    }
    return uri.substring(0, uri.length.clamp(0, 20));
  }

  // Removed unsupported _initAlertHandler, _persistResumeData, _initResumeTimer, and _getResumeDir.

  void dispose() {
    _dbWriteTimer?.cancel();
    _alertSubscription?.cancel();
  }
}
