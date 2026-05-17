import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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
import '../../../settings/presentation/controllers/settings_notifier.dart';
import '../../../../core/services/folder_service.dart';
import '../../../../core/services/notification_service.dart';

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

enum TorrentFilter { all, downloading, completed }

@riverpod
class ActiveFilter extends _$ActiveFilter {
  @override
  TorrentFilter build() => TorrentFilter.all;

  void setFilter(TorrentFilter filter) {
    state = filter;
  }
}

@riverpod
List<TorrentStatus> filteredTorrents(Ref ref) {
  final torrentsAsync = ref.watch(torrentNotifierProvider);
  final activeFilter = ref.watch(activeFilterProvider);

  final torrents = torrentsAsync.valueOrNull ?? [];
  if (torrents.isEmpty) return [];

  // A. Filtering
  final filtered = torrents.where((t) {
    switch (activeFilter) {
      case TorrentFilter.downloading:
        return !t.isEffectivelyComplete && t.state.isActive;
      case TorrentFilter.completed:
        return t.isEffectivelyComplete;
      case TorrentFilter.all:
        return true;
    }
  }).toList();

  // B. Immutable Sorting with Secondary Stability Fallback
  final sorted = [...filtered];
  if (activeFilter == TorrentFilter.completed) {
    sorted.sort((a, b) {
      final aTime = a.completedAt ?? a.addedAt;
      final bTime = b.completedAt ?? b.addedAt;
      final byCompleted = bTime.compareTo(aTime);
      if (byCompleted != 0) return byCompleted;
      return b.id.compareTo(a.id); // secondary stable sorting
    });
  } else {
    sorted.sort((a, b) {
      final byActivity = b.lastActivityAt.compareTo(a.lastActivityAt);
      if (byActivity != 0) return byActivity;
      return b.id.compareTo(a.id); // secondary stable sorting
    });
  }

  return sorted;
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  List<ConnectivityResult> _currentConnectivity = [ConnectivityResult.none];
  final _wifiAutoPausedTorrents =
      <String, bool>{}; // Map of torrentId -> wasSeeding
  final _pendingStopTimers = <String, Timer>{};
  StreamSubscription<NotificationActionEvent>? _actionSub;

  /// Optimistic state overrides applied immediately on user action.
  /// These shield the UI from reverting during the DB-write race window.
  /// Cleared once the live stream confirms the new state for each torrent.
  final _optimisticOverrides = <String, ({bool isPaused, bool isStopped})>{};

  @override
  Future<List<TorrentStatus>> build() async {
    WidgetsBinding.instance.addObserver(this);

    // Initialize current connectivity
    Connectivity().checkConnectivity().then((results) {
      _currentConnectivity = results;
      _enforceWifiOnly(results);
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      _currentConnectivity = results;
      _enforceWifiOnly(results);
    });

    ref.listen(settingsNotifierProvider, (previous, next) async {
      if (previous?.wifiOnlyMode != next.wifiOnlyMode) {
        final results = await Connectivity().checkConnectivity();
        _currentConnectivity = results;
        _enforceWifiOnly(results);
      }
    });

    _actionSub = NotificationService.instance.actionStream.listen((event) {
      if (event.actionId == NotificationActions.pause) {
        pauseTorrent(event.torrentId);
      } else if (event.actionId == NotificationActions.resume) {
        resumeTorrent(event.torrentId);
      } else if (event.actionId == NotificationActions.stop) {
        stopTorrent(event.torrentId);
      } else if (event.actionId == NotificationActions.openFolder) {
        FolderService.instance.openDownloadTarget(
          savePath: event.savePath,
          name: event.name,
        );
      }
    });

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _sub?.cancel();
      _connectivitySub?.cancel();
      _actionSub?.cancel();
      for (final timer in _pendingStopTimers.values) {
        timer.cancel();
      }
      _pendingStopTimers.clear();
    });

    final repo = ref.watch(torrentRepositoryProvider);

    // Subscribe to live stream; rebuild state on each emission
    _sub = repo.statusStream.listen(
      (statuses) {
        // Apply any pending optimistic overrides and prune ones that have
        // been confirmed by the live stream.
        List<TorrentStatus> resolved = statuses;
        if (_optimisticOverrides.isNotEmpty) {
          final toRemove = <String>{};
          resolved = statuses.map((t) {
            final override = _optimisticOverrides[t.id];
            if (override == null) return t;

            // Check whether the live stream has caught up to our optimistic state.
            final confirmed = t.isPaused == override.isPaused &&
                t.isStopped == override.isStopped;
            if (confirmed) {
              toRemove.add(t.id);
              return t;
            }

            // Not yet confirmed — keep overriding.
            TorrentState overrideState = t.state;
            if (override.isStopped) {
              overrideState = TorrentState.stopped;
            } else if (override.isPaused) {
              overrideState = TorrentState.paused;
            } else {
              // Resuming
              if (t.state == TorrentState.stopped ||
                  t.state == TorrentState.paused) {
                overrideState = TorrentState.downloading;
              }
            }
            return t.copyWith(
              isPaused: override.isPaused,
              isStopped: override.isStopped,
              state: overrideState,
            );
          }).toList();
          toRemove.forEach(_optimisticOverrides.remove);
        }

        state = AsyncValue.data(resolved);
        // Push notification update (Hardening #5)
        ForegroundServiceManager.instance.pushUpdate(statuses);

        final config = ref.read(settingsNotifierProvider);

        // ── WiFi-only Mode Enforcement ────────────────────────────────
        final hasWifiResult =
            _currentConnectivity.contains(ConnectivityResult.wifi);
        if (config.wifiOnlyMode && !hasWifiResult) {
          for (final torrent in statuses) {
            final isDownloadingOrSeeding =
                torrent.state == TorrentState.downloading ||
                    torrent.state == TorrentState.seeding;
            if (isDownloadingOrSeeding && !torrent.isPaused) {
              _wifiAutoPausedTorrents[torrent.id] =
                  torrent.state == TorrentState.seeding;
              pauseTorrent(torrent.id);
              AppLogger.i(
                  '[WiFi Guard] Live block: auto-paused active torrent: ${torrent.id}');
            }
          }
        }

        // ── Auto-pause seeding if setting enabled ─────────────────────
        if (config.stopSeedingWhenFinished) {
          for (final torrent in statuses) {
            if (torrent.state == TorrentState.finished && !torrent.isPaused) {
              if (!_pendingStopTimers.containsKey(torrent.id)) {
                _pendingStopTimers[torrent.id] =
                    Timer(const Duration(seconds: 15), () {
                  _pendingStopTimers.remove(torrent.id);
                  pauseTorrent(torrent.id);
                  AppLogger.i(
                      '[Notifier] Auto-paused finished torrent after 15s delay: ${torrent.id}');
                });
                AppLogger.i(
                    '[Notifier] Scheduled 15s stop-seeding delay for torrent: ${torrent.id}');
              }
            } else {
              // Cancel pending timer if torrent is already paused, deleted or resumed back to downloading
              if (_pendingStopTimers.containsKey(torrent.id)) {
                _pendingStopTimers[torrent.id]?.cancel();
                _pendingStopTimers.remove(torrent.id);
                AppLogger.i(
                    '[Notifier] Cancelled pending stop-seeding timer for torrent: ${torrent.id}');
              }
            }
          }
        } else {
          // If the setting was toggled off dynamically, clear all pending timers
          if (_pendingStopTimers.isNotEmpty) {
            for (final timer in _pendingStopTimers.values) {
              timer.cancel();
            }
            _pendingStopTimers.clear();
            AppLogger.i(
                '[Notifier] Settings disabled: cleared all pending stop-seeding timers');
          }
        }
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

  Future<void> _enforceWifiOnly(List<ConnectivityResult> results) async {
    final settings = ref.read(settingsNotifierProvider);
    if (!settings.wifiOnlyMode) {
      // If Wifi-only mode is turned OFF, resume any torrents we previously auto-paused
      if (_wifiAutoPausedTorrents.isNotEmpty) {
        AppLogger.i(
            '[WiFi Guard] WiFi-only mode disabled. Auto-resuming torrents: ${_wifiAutoPausedTorrents.keys}');
        for (final id in List.from(_wifiAutoPausedTorrents.keys)) {
          _wifiAutoPausedTorrents.remove(id);
          try {
            await resumeTorrent(id);
          } catch (e) {
            AppLogger.w('[WiFi Guard] Failed to auto-resume torrent: $id',
                error: e);
          }
        }
      }
      return;
    }

    final hasWifi = results.contains(ConnectivityResult.wifi);
    if (!hasWifi) {
      // Not on WiFi! Pause any active downloading or seeding torrents
      final statuses = state.valueOrNull ?? [];
      for (final torrent in statuses) {
        final isDownloadingOrSeeding =
            torrent.state == TorrentState.downloading ||
                torrent.state == TorrentState.seeding;
        if (isDownloadingOrSeeding && !torrent.isPaused) {
          _wifiAutoPausedTorrents[torrent.id] =
              torrent.state == TorrentState.seeding;
          AppLogger.i(
              '[WiFi Guard] Device not on WiFi. Auto-pausing torrent: ${torrent.id}');
          try {
            await pauseTorrent(torrent.id);
          } catch (e) {
            AppLogger.w(
                '[WiFi Guard] Failed to auto-pause torrent: ${torrent.id}',
                error: e);
          }
        }
      }
    } else {
      // Back on WiFi! Resume any torrents we auto-paused
      if (_wifiAutoPausedTorrents.isNotEmpty) {
        AppLogger.i(
            '[WiFi Guard] Connected to WiFi! Auto-resuming torrents: ${_wifiAutoPausedTorrents.keys}');
        for (final id in List.from(_wifiAutoPausedTorrents.keys)) {
          _wifiAutoPausedTorrents.remove(id);
          try {
            await resumeTorrent(id);
          } catch (e) {
            AppLogger.w('[WiFi Guard] Failed to auto-resume torrent: $id',
                error: e);
          }
        }
      }
    }
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
    _optimisticOverrides[id] = (isPaused: true, isStopped: false);
    _updateOptimisticStatus(id, isPaused: true);
    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.pauseTorrent(id);
      AppLogger.i('[Notifier] Successfully paused torrent: $id');
    } catch (e, st) {
      _optimisticOverrides.remove(id);
      AppLogger.e('[Notifier] Failed to pause torrent: $id',
          error: e, stack: st);
      // Let the live stream handle the rollback/actual state
      rethrow;
    }
  }

  Future<void> pauseMultiple(List<String> ids) async {
    for (final id in ids) {
      _optimisticOverrides[id] = (isPaused: true, isStopped: false);
    }
    _updateOptimisticStatusMultiple(ids, isPaused: true);
    try {
      final repo = ref.read(torrentRepositoryProvider);
      // Repository handles the loop/batching
      await repo.pauseMultiple(ids);
      AppLogger.i('[Notifier] Successfully paused ${ids.length} torrents');
    } catch (e, st) {
      for (final id in ids) {
        _optimisticOverrides.remove(id);
      }
      AppLogger.e('[Notifier] Failed to pause multiple torrents',
          error: e, stack: st);
      rethrow;
    }
  }

  Future<void> stopTorrent(String id) async {
    _optimisticOverrides[id] = (isPaused: true, isStopped: true);
    _updateOptimisticStatus(id, isPaused: true, isStopped: true);
    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.stopTorrent(id);
      AppLogger.i('[Notifier] Successfully stopped torrent: $id');
    } catch (e, st) {
      _optimisticOverrides.remove(id);
      AppLogger.e('[Notifier] Failed to stop torrent: $id',
          error: e, stack: st);
      rethrow;
    }
  }

  Future<void> stopMultiple(List<String> ids) async {
    for (final id in ids) {
      _optimisticOverrides[id] = (isPaused: true, isStopped: true);
    }
    _updateOptimisticStatusMultiple(ids, isPaused: true, isStopped: true);
    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.stopMultiple(ids);
      AppLogger.i('[Notifier] Successfully stopped ${ids.length} torrents');
    } catch (e, st) {
      for (final id in ids) {
        _optimisticOverrides.remove(id);
      }
      AppLogger.e('[Notifier] Failed to stop multiple torrents',
          error: e, stack: st);
      rethrow;
    }
  }

  Future<void> resumeTorrent(String id) async {
    _optimisticOverrides[id] = (isPaused: false, isStopped: false);
    _updateOptimisticStatus(id, isPaused: false, isStopped: false);
    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.resumeTorrent(id);
      AppLogger.i('[Notifier] Successfully resumed torrent: $id');
    } catch (e, st) {
      _optimisticOverrides.remove(id);
      AppLogger.e('[Notifier] Failed to resume torrent: $id',
          error: e, stack: st);
      rethrow;
    }
  }

  Future<void> resumeMultiple(List<String> ids) async {
    for (final id in ids) {
      _optimisticOverrides[id] = (isPaused: false, isStopped: false);
    }
    _updateOptimisticStatusMultiple(ids, isPaused: false, isStopped: false);
    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.resumeMultiple(ids);
      AppLogger.i('[Notifier] Successfully resumed ${ids.length} torrents');
    } catch (e, st) {
      for (final id in ids) {
        _optimisticOverrides.remove(id);
      }
      AppLogger.e('[Notifier] Failed to resume multiple torrents',
          error: e, stack: st);
      rethrow;
    }
  }

  void _updateOptimisticStatus(String id, {bool? isPaused, bool? isStopped}) {
    final previousList = state.asData?.value;
    if (previousList == null) return;

    final updated = previousList.map((t) {
      if (t.id == id) {
        TorrentState newState = t.state;
        if (isStopped == true) {
          newState = TorrentState.stopped;
        } else if (isPaused == true && isStopped != true) {
          // Soft pause — keep engine state but mark paused flag
          newState = TorrentState.paused;
        } else if (isPaused == false && isStopped == false) {
          // Resuming — restore to downloading so the pause button shows immediately
          if (t.state == TorrentState.stopped ||
              t.state == TorrentState.paused) {
            newState = TorrentState.downloading;
          }
        }
        return t.copyWith(
          isPaused: isPaused ?? t.isPaused,
          isStopped: isStopped ?? t.isStopped,
          state: newState,
        );
      }
      return t;
    }).toList();

    state = AsyncValue.data(updated);
  }

  void _updateOptimisticStatusMultiple(List<String> ids,
      {bool? isPaused, bool? isStopped}) {
    final previousList = state.asData?.value;
    if (previousList == null) return;

    final idSet = ids.toSet();
    final updated = previousList.map((t) {
      if (idSet.contains(t.id)) {
        TorrentState newState = t.state;
        if (isStopped == true) {
          newState = TorrentState.stopped;
        } else if (isPaused == true && isStopped != true) {
          newState = TorrentState.paused;
        } else if (isPaused == false && isStopped == false) {
          if (t.state == TorrentState.stopped ||
              t.state == TorrentState.paused) {
            newState = TorrentState.downloading;
          }
        }
        return t.copyWith(
          isPaused: isPaused ?? t.isPaused,
          isStopped: isStopped ?? t.isStopped,
          state: newState,
        );
      }
      return t;
    }).toList();

    state = AsyncValue.data(updated);
  }

  Future<void> deleteTorrent(String id, {bool deleteFiles = false}) async {
    final previous = state;
    final previousList = previous.asData?.value;
    if (previousList != null) {
      final updated =
          previousList.where((torrent) => torrent.id != id).toList();
      state = AsyncValue.data(updated);
    }

    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.deleteTorrent(id, deleteFiles: deleteFiles);
      AppLogger.i(
          '[Notifier] Successfully deleted torrent: $id (deleteFiles=$deleteFiles)');
    } catch (e, st) {
      if (previousList != null) {
        state = AsyncValue.data(previousList);
      }
      AppLogger.e('[Notifier] Failed to delete torrent: $id',
          error: e, stack: st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> pauseAll() async {
    final repo = ref.read(torrentRepositoryProvider);
    await repo.pauseAll();
  }

  Future<void> stopAll() async {
    final repo = ref.read(torrentRepositoryProvider);
    await repo.stopAll();
  }

  Future<void> resumeAll() async {
    final repo = ref.read(torrentRepositoryProvider);
    await repo.resumeAll();
  }

  Future<void> deleteMultiple(List<String> ids,
      {bool deleteFiles = false}) async {
    // Optimistic UI: remove all selected torrents from state immediately
    final previousList = state.asData?.value;
    if (previousList != null) {
      final idSet = ids.toSet();
      final updated = previousList.where((t) => !idSet.contains(t.id)).toList();
      state = AsyncValue.data(updated);
    }

    try {
      final repo = ref.read(torrentRepositoryProvider);
      await repo.deleteMultiple(ids, deleteFiles: deleteFiles);
      AppLogger.i(
          '[Notifier] deleteMultiple: removed ${ids.length} torrents (deleteFiles=$deleteFiles)');
    } catch (e, st) {
      // Rollback on failure
      if (previousList != null) {
        state = AsyncValue.data(previousList);
      }
      AppLogger.e('[Notifier] deleteMultiple failed', error: e, stack: st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // 🛡️ Emergency save on background/kill
      final repo = ref.read(torrentRepositoryProvider);
      repo.forceSaveAllResumeData();
    }
  }
}

// ─── Selection Controller ───────────────────────────────────────────────────

@riverpod
class SelectedTorrents extends _$SelectedTorrents {
  bool _manualMode = false;

  @override
  Set<String> build() => {};

  void toggle(String id) {
    if (state.contains(id)) {
      state = Set.from(state)..remove(id);
    } else {
      state = {...state, id};
    }
    if (state.isEmpty) _manualMode = false;
  }

  void enterSelectionMode() {
    _manualMode = true;
    // Force a real state change so Riverpod triggers a rebuild.
    // notifyListeners() alone does NOT cause ConsumerWidgets to rebuild
    // because Riverpod only rebuilds on state object identity change.
    state = Set.from(state);
  }

  void selectAll(List<String> ids) {
    state = Set.from(ids);
    _manualMode = true;
  }

  void clear() {
    state = {};
    _manualMode = false;
  }

  bool get isSelectionMode => _manualMode || state.isNotEmpty;
}
