import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/foreground_service_manager.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/torrent_engine_service.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/torrent_repository_impl.dart';
import '../../../../domain/entities/torrent_status.dart';
import '../../../../domain/repositories/torrent_repository.dart';

part 'torrent_notifier.g.dart';

// ─── Infrastructure Providers ─────────────────────────────────────────────────

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
TorrentRepository torrentRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final engine = TorrentEngineService.instance;
  final repo = TorrentRepositoryImpl(database: db, engine: engine);
  ref.onDispose(repo.dispose);
  return repo;
}

// ─── Main Notifier ────────────────────────────────────────────────────────────

/// Central state manager for all torrent operations.
///
/// Responsibilities:
/// - Subscribes to the live engine stream
/// - Exposes [AsyncValue<List<TorrentStatus>>] to the UI
/// - Pushes foreground service notification updates on each state change (Hardening #5)
/// - Delegates write operations to [TorrentRepository]
@riverpod
class TorrentNotifier extends _$TorrentNotifier with WidgetsBindingObserver {
  StreamSubscription<List<TorrentStatus>>? _sub;

  @override
  Future<List<TorrentStatus>> build() async {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _sub?.cancel();
    });

    final repo = ref.watch(torrentRepositoryProvider);

    // Subscribe to live stream; rebuild state on each emission
    _sub = repo.statusStream.listen(
      (statuses) {
        state = AsyncValue.data(statuses);
        // Push notification update (Hardening #5)
        ForegroundServiceManager.instance.pushUpdate(statuses);
      },
      onError: (Object e, StackTrace st) {
        state = AsyncValue.error(e, st);
        AppLogger.e('[TorrentNotifier] Stream error', error: e, stack: st);
      },
    );

    // Return DB snapshot as initial state while stream warms up
    final stored = await repo.getStoredTorrents();
    ForegroundServiceManager.instance.pushUpdate(stored);
    return stored;
  }

  // ─── Actions ────────────────────────────────────────────────────

  Future<void> addMagnet(String uri, {String? savePath}) async {
    state = const AsyncValue.loading();
    final repo = ref.read(torrentRepositoryProvider);
    state = await AsyncValue.guard(
      () => repo
          .addMagnet(uri, savePath: savePath)
          .then((_) => repo.getStoredTorrents()),
    );
  }

  Future<void> addTorrentFile(String filePath, {String? savePath}) async {
    state = const AsyncValue.loading();
    final repo = ref.read(torrentRepositoryProvider);
    state = await AsyncValue.guard(
      () => repo
          .addTorrentFile(filePath, savePath: savePath)
          .then((_) => repo.getStoredTorrents()),
    );
  }

  Future<void> pauseTorrent(String id) async {
    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.pauseTorrent(id);
      AppLogger.i('[Notifier] Successfully paused torrent: $id');
    } catch (e, st) {
      AppLogger.e('[Notifier] Failed to pause torrent: $id',
          error: e, stack: st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resumeTorrent(String id) async {
    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.resumeTorrent(id);
      AppLogger.i('[Notifier] Successfully resumed torrent: $id');
    } catch (e, st) {
      AppLogger.e('[Notifier] Failed to resume torrent: $id',
          error: e, stack: st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteTorrent(String id, {bool deleteFiles = false}) async {
    final previous = state;
    final previousList = previous.asData?.value;
    if (previousList != null) {
      final updated =
          previousList.where((torrent) => torrent.id != id).toList();
      state = AsyncValue.data(updated);
      ForegroundServiceManager.instance.pushUpdate(updated);
    }

    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.deleteTorrent(id, deleteFiles: deleteFiles);
      AppLogger.i(
          '[Notifier] Successfully deleted torrent: $id (deleteFiles=$deleteFiles)');
    } catch (e, st) {
      if (previousList != null) {
        state = AsyncValue.data(previousList);
        ForegroundServiceManager.instance.pushUpdate(previousList);
      }
      AppLogger.e('[Notifier] Failed to delete torrent: $id',
          error: e, stack: st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // 🛡️ Emergency save on background/kill
      final repo = ref.read(torrentRepositoryProvider);
      repo.forceSaveAllResumeData();
    }
  }
}
