import 'dart:io';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/torrent_status.dart';
import '../../domain/repositories/torrent_repository.dart';
import 'logger_service.dart';
import 'torrent_engine_service.dart';

/// Singleton that ensures a single libtorrent session exists across the app lifecycle.
///
/// Handles:
/// - Engine initialization with retry backoff
/// - DB snapshot restoration with smart recheck logic:
///     • Completed → add to engine, trigger recheck
///     • Paused    → add to engine, immediately pause
///     • Others    → add to engine normally
class EngineProcessManager {
  EngineProcessManager._();
  static final EngineProcessManager instance = EngineProcessManager._();

  final TorrentEngineService _engine = TorrentEngineService.instance;
  bool _started = false;

  /// Initializes the engine and restores stored torrents from [storedTorrents].
  /// Must be called once at app startup (from SplashScreen).
  Future<void> initialize({
    required List<TorrentStatus> storedTorrents,
    required AppDatabase database,
    EngineConfig config = const EngineConfig(),
  }) async {
    if (_started) {
      AppLogger.w('[ProcessManager] Already started — ignoring duplicate init');
      return;
    }

    AppLogger.i('[ProcessManager] Initializing engine…');
    await _engine.initialize(config: config);
    _started = true;

    AppLogger.i(
        '[ProcessManager] Restoring ${storedTorrents.length} torrents…');
    await _restoreAndValidate(storedTorrents, database);
  }

  bool get isStarted => _started;

  /// Re-adds all stored torrents using smart resume logic.
  Future<void> _restoreAndValidate(
    List<TorrentStatus> stored,
    AppDatabase db,
  ) async {
    for (final t in stored) {
      try {
        await _restoreSingleTorrent(t, db);
      } catch (e, st) {
        AppLogger.e(
          '[ProcessManager] Failed to restore torrent ${t.id}',
          error: e,
          stack: st,
        );
      }
    }
  }

  Future<void> _restoreSingleTorrent(TorrentStatus t, AppDatabase db) async {
    final filesExist = await _verifyFilesExist(t);
    int? engineId;

    // 1. 🛡️ Restoration: Re-add to engine
    if ((t.magnetUri ?? '').isNotEmpty) {
      engineId = _engine.addMagnet(t.magnetUri!, t.savePath);
    } else if ((t.torrentFilePath ?? '').isNotEmpty) {
      engineId = _engine.addTorrentFile(t.torrentFilePath!, t.savePath);
    }

    if (engineId != null) {
      // 2. ⏸️ Apply Paused State
      if (t.isPaused) {
        _engine.pause(engineId);
        AppLogger.i(
            '[ProcessManager] Restored "${t.name}" as PAUSED (engine id $engineId)');
      } else {
        AppLogger.i(
            '[ProcessManager] Restored "${t.name}" (engine id $engineId)');
      }

      // 3. 🔍 Sync with Disk: If files exist, force a recheck to restore progress quickly.
      if (filesExist) {
        _engine.forceRecheck(engineId);
        AppLogger.d(
            '[ProcessManager] Triggered recheck for "${t.name}" to sync with disk');
      }
    } else {
      await db.upsertTorrent(
        TorrentsTableCompanion(
          id: Value(t.id),
          name: Value(t.name),
          magnetUri: Value(t.magnetUri),
          torrentFilePath: Value(t.torrentFilePath),
          savePath: Value(t.savePath),
          totalSize: Value(t.totalSize),
          downloadedBytes: Value(t.downloadedBytes),
          progress: Value(t.progress),
          state: Value(TorrentState.error.name),
          isPaused: const Value(true),
          isCompleted: Value(t.isCompleted),
          addedAt: Value(t.addedAt),
          isSequentialDownload: Value(t.isSequentialDownload),
        ),
      );
      AppLogger.e(
        '[ProcessManager] Failed to re-add "${t.name}" to engine '
        '(missing restore source: magnetUri=${t.magnetUri != null && t.magnetUri!.isNotEmpty}, '
        'torrentFilePath=${t.torrentFilePath != null && t.torrentFilePath!.isNotEmpty})',
      );
    }
  }

  /// Returns true if the torrent's data exists on disk.
  Future<bool> _verifyFilesExist(TorrentStatus t) async {
    final subPath = '${t.savePath}/${t.name}';
    final file = File(subPath);
    final dir = Directory(subPath);

    if (file.existsSync()) return true;
    if (dir.existsSync()) {
      try {
        return dir.listSync().isNotEmpty;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Checks if the engine is still alive; re-initializes if not.
  /// Called from the foreground task handler on service restart.
  Future<void> ensureRunning({
    required List<TorrentStatus> storedTorrents,
    required AppDatabase database,
    EngineConfig config = const EngineConfig(),
  }) async {
    if (!_started || !_engine.isInitialized) {
      AppLogger.w('[ProcessManager] Engine not running — restarting…');
      _started = false;
      await initialize(
        storedTorrents: storedTorrents,
        database: database,
        config: config,
      );
    }
  }
}
