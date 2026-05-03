import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../data/models/torrent_model.dart';
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
        '[ProcessManager] Restoring ${storedTorrents.length} torrents (background)…');
    // Start restoration without blocking the caller (SplashScreen)
    // to prevent UI freezes on cold-start with many torrents.
    unawaited(_restoreAndValidate(storedTorrents, database));
  }

  bool get isStarted => _started;

  /// Re-adds all stored torrents using smart resume logic.
  Future<void> _restoreAndValidate(
    List<TorrentStatus> stored,
    AppDatabase db,
  ) async {
    // Process in parallel batches of 5 to balance speed and stability.
    const batchSize = 5;
    for (var i = 0; i < stored.length; i += batchSize) {
      final end =
          (i + batchSize < stored.length) ? i + batchSize : stored.length;
      final batch = stored.sublist(i, end);

      try {
        await Future.wait(batch.map((t) => _restoreSingleTorrent(t, db)));
      } catch (e) {
        AppLogger.e('[ProcessManager] Batch restoration error', error: e);
      }
    }
    AppLogger.i('[ProcessManager] Restoration complete');
  }

  Future<void> _restoreSingleTorrent(TorrentStatus t, AppDatabase db) async {
    final filesExist = await _verifyFilesExist(t);
    int? engineId;

    var actuallyUsedFastResume = false;
    final hasValidResume = t.resumeData != null && 
                          t.resumeData!.length > 100 && 
                          Directory(t.savePath).existsSync() &&
                          t.totalSize > 0;

    if (hasValidResume) {
      try {
        if ((t.magnetUri ?? '').isNotEmpty) {
          engineId = _engine.addMagnetWithResume(
              t.magnetUri!, t.savePath, t.resumeData!);
        } else if ((t.torrentFilePath ?? '').isNotEmpty) {
          engineId = _engine.addTorrentFileWithResume(
              t.torrentFilePath!, t.savePath, t.resumeData!);
        }
        AppLogger.i('[ProcessManager] Restored "${t.name}" with fast-resume (id $engineId)');
        actuallyUsedFastResume = true;
      } catch (e) {
        AppLogger.w('[ProcessManager] Fast-resume failed for "${t.name}", falling back to recheck: $e');
        // Fallback to normal add
        if ((t.magnetUri ?? '').isNotEmpty) {
          engineId = _engine.addMagnet(t.magnetUri!, t.savePath);
        } else if ((t.torrentFilePath ?? '').isNotEmpty) {
          engineId = _engine.addTorrentFile(t.torrentFilePath!, t.savePath);
        }
      }
    } else {
      // No resume data available → normal add
      if ((t.magnetUri ?? '').isNotEmpty) {
        engineId = _engine.addMagnet(t.magnetUri!, t.savePath);
      } else if ((t.torrentFilePath ?? '').isNotEmpty) {
        engineId = _engine.addTorrentFile(t.torrentFilePath!, t.savePath);
      }
    }

    if (engineId != null) {
      final newId = engineId.toString();

      // 2. 🆔 ID Sync
      if (newId != t.id) {
        AppLogger.i('[ProcessManager] Syncing ID for "${t.name}": ${t.id} → $newId');
        await db.deleteTorrentById(t.id);
        await db.upsertTorrent(TorrentModel.toCompanion(t.copyWith(id: newId)));
      }

      // 3. ⏸️ Apply Paused State
      if (t.isPaused) {
        _engine.pause(engineId);
        AppLogger.i('[ProcessManager] Restored "${t.name}" as PAUSED');
      }

      // 4. 🔍 Sync with Disk (Fallback/Completion Logic)
      if (!actuallyUsedFastResume && filesExist) {
        _engine.forceRecheck(engineId);
        AppLogger.d('[ProcessManager] Triggered fallback recheck for "${t.name}"');
      }
    }
 else {
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
