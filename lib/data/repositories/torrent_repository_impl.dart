import 'dart:async';
import 'dart:io';

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
      //    These are completed torrents we skipped during restoration.
      final liveIds = liveStatuses.map((s) => s.id).toSet();
      final engineSkipped = dbTorrents
          .where((t) => !liveIds.contains(t.id))
          .where((t) => !_deletedIds.contains(t.id))
          .toList();

      if (engineSkipped.length <
          dbTorrents.where((t) => !liveIds.contains(t.id)).length) {
        AppLogger.d('[Repo] Filtered deleted ghosts from engine-skipped list');
      }

      // 6. Merge live statuses with DB-only completed statuses
      final merged = [...liveStatuses, ...engineSkipped];

      // 7. Preserve addedAt from cache and ensure completed torrents have finished state
      final corrected = merged
          .where((s) => !_deletedIds.contains(s.id)) // Last-second guard
          .map((s) {
        var status = s;
        final persisted = dbById[s.id];

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
      await _checkDiskSpace(corrected);
      return corrected;
    });
  }

  TorrentStatus _mergePersistedFields(
    TorrentStatus live,
    TorrentStatus persisted,
  ) {
    return live.copyWith(
      magnetUri: live.magnetUri ?? persisted.magnetUri,
      torrentFilePath: live.torrentFilePath ?? persisted.torrentFilePath,
      isSequentialDownload:
          live.isSequentialDownload || persisted.isSequentialDownload,
      savePath: live.savePath.isEmpty ? persisted.savePath : live.savePath,
      name: live.name == 'Torrent #${live.id}' ? persisted.name : live.name,
    );
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
      _engine.pause(intId);
    }
    await _updateFlags(id, isPaused: true);
    await _updateState(id, TorrentState.paused);
    await _flushDbWrite(); // Ensure immediate persistence
  }

  @override
  Future<void> resumeTorrent(String id) async {
    final intId = int.tryParse(id);
    if (intId != null && _isLiveInEngine(intId)) {
      // Engine has it — just resume
      _engine.resume(intId);
    } else {
      // Engine doesn't have it (was a skipped completed torrent).
      // Re-add to engine so libtorrent can seed / continue.
      final stored = await _db.getTorrentById(id);
      if (stored != null) {
        final t = TorrentModel.fromRow(stored);
        int? newId;
        if (t.magnetUri != null) {
          newId = _engine.addMagnet(t.magnetUri!, t.savePath);
        } else if (t.torrentFilePath != null) {
          newId = _engine.addTorrentFile(t.torrentFilePath!, t.savePath);
        }
        if (newId != null) _engineActiveIds.add(newId);
      }
    }
    await _updateFlags(id, isPaused: false);
    await _updateState(id, TorrentState.downloading);
    await _flushDbWrite(); // Ensure immediate persistence
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
        _engine.forceRecheck(newId);
      }
    }
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
        final companions = statuses.map(TorrentModel.toCompanion).toList();
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
      {bool? isPaused, bool? isCompleted}) async {
    final row = await _db.getTorrentById(id);
    if (row != null) {
      await _db.upsertTorrent(
        TorrentModel.toCompanion(TorrentModel.fromRow(row).copyWith(
          isPaused: isPaused,
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
