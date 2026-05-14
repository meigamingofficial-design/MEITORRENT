import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../core/utils/speed_formatter.dart';
import '../../domain/entities/torrent_status.dart';
import '../native/libtorrent_flutter_base.dart' as lt;
import '../native/models.dart' as lt_models;
import 'logger_service.dart';
import 'notification_service.dart';
import 'torrent_engine_service.dart';

// ─── Top-level entry point (required by flutter_foreground_task) ──────────────

/// This function runs in a separate isolate when the foreground service starts.
@pragma('vm:entry-point')
void torrentServiceCallback() {
  FlutterForegroundTask.setTaskHandler(TorrentTaskHandler());
}

/// Handles foreground service lifecycle events.
class TorrentTaskHandler extends TaskHandler {
  int? _sessionAddress;
  String? _savePath;
  Timer? _pollingTimer;
  DateTime? _lastMainIsolateUpdate;
  final Map<String, int> _cachedTimestamps = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    AppLogger.i('[FGService] Started at $timestamp via $starter');
  }

  /// Called when the main isolate pushes data via [FlutterForegroundTask.sendDataToTask].
  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      // 🚀 Instant Hand-off: If the app is minimizing, let the background take over NOW
      if (data['minimize'] == true) {
        _lastMainIsolateUpdate = null;
        return;
      }

      _lastMainIsolateUpdate = DateTime.now();

      // 1. Update notification text
      final title = data['title'] as String? ?? 'Meitorrent';
      final text = data['text'] as String? ?? '';

      FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );

      // 2. Capture session address, save path, and real timestamps
      final addr = data['sessionAddress'] as int?;
      final path = data['savePath'] as String?;
      final timestamps = data['timestamps'] as Map?;

      if (timestamps != null) {
        for (final entry in timestamps.entries) {
          _cachedTimestamps[entry.key.toString()] = entry.value as int;
        }
      }

      if (addr != null && addr != _sessionAddress) {
        _sessionAddress = addr;
        _savePath = path;
        _startBackgroundPolling();
      }
    }
  }

  void _startBackgroundPolling() {
    _pollingTimer?.cancel();
    if (_sessionAddress == null) return;

    AppLogger.i(
        '[FGService] Attaching to native engine at 0x${_sessionAddress!.toRadixString(16)}');

    lt.LibtorrentFlutter.attach(
      sessionAddress: _sessionAddress!,
      defaultSavePath: _savePath,
      pollInterval: const Duration(seconds: 1),
    );

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastMainIsolateUpdate != null &&
          DateTime.now().difference(_lastMainIsolateUpdate!) <
              const Duration(seconds: 4)) {
        return;
      }

      final engine = lt.LibtorrentFlutter.instanceInternal;
      if (engine == null) return;

      final rawTorrents = engine.torrents.values.toList();
      final torrents = rawTorrents.map(_mapToStatus).toList();

      final active = torrents
          .where((t) => t.state.isActive && !t.isPaused && !t.isCompleted)
          .toList();
      final completed = torrents
          .where((t) => t.isCompleted || t.progress >= 1.0)
          .toList();
      final paused = torrents
          .where((t) => (t.isPaused || t.isStopped) && !t.isCompleted && t.progress < 1.0)
          .toList();

      final String summaryText;
      if (active.isNotEmpty) {
        final totalDown = active.fold<int>(0, (s, t) => s + t.downloadSpeed);
        summaryText =
            '${active.length} active · ↓ ${SpeedFormatter.format(totalDown)}';
      } else if (completed.isNotEmpty) {
        summaryText =
            '${completed.length} download${completed.length == 1 ? '' : 's'} complete';
      } else if (paused.isNotEmpty) {
        summaryText =
            '${paused.length} torrent${paused.length == 1 ? '' : 's'} paused';
      } else {
        summaryText = 'No torrents added';
      }

      FlutterForegroundTask.updateService(
        notificationTitle: 'Meitorrent',
        notificationText: summaryText,
      );
    });
  }

  TorrentStatus _mapToStatus(lt_models.TorrentInfo info) {
    final bool isReallyDone = info.totalWanted > 0 &&
        info.totalDone >= info.totalWanted &&
        info.progress >= 1.0;

    return TorrentStatus(
      id: info.id.toString(),
      name: info.name,
      progress: info.progress.clamp(0.0, 1.0),
      downloadSpeed: info.downloadRate,
      uploadSpeed: info.uploadRate,
      peers: info.numPeers,
      seeds: info.numSeeds,
      state: info.isPaused
          ? TorrentState.paused
          : (isReallyDone ? TorrentState.finished : TorrentState.downloading),
      totalSize: info.totalWanted,
      downloadedBytes: info.totalDone,
      uploadedBytes: info.totalUploaded,
      savePath: info.savePath,
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        _cachedTimestamps[info.id.toString()] ?? info.id.hashCode & 0x0FFFFFFF,
      ),
      lastActivityAt: DateTime.fromMillisecondsSinceEpoch(
        _cachedTimestamps[info.id.toString()] ?? info.id.hashCode & 0x0FFFFFFF,
      ),
      completedAt: isReallyDone ? DateTime.now() : null,
      ratio: info.totalWanted > 0 ? info.totalUploaded / info.totalWanted : 0.0,
      isPaused: info.isPaused,
      isCompleted: isReallyDone,
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _pollingTimer?.cancel();
    AppLogger.i('[FGService] Destroyed at $timestamp (timeout=$isTimeout)');
  }
}

// ─── Manager ──────────────────────────────────────────────────────────────────

/// Manages starting/stopping the foreground task and pushing notification updates.
class ForegroundServiceManager {
  ForegroundServiceManager._();
  static final ForegroundServiceManager instance = ForegroundServiceManager._();

  bool _serviceStarted = false;
  Timer? _stopServiceTimer;

  static void initCommunicationPort() {
    FlutterForegroundTask.initCommunicationPort();
  }

  Future<void> setup() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'meitorrent_download',
        channelName: 'Download Progress',
        channelDescription: 'Shows active torrent download progress',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Map<String, dynamic>? _pendingData;

  void _cancelStopServiceTimer() {
    _stopServiceTimer?.cancel();
    _stopServiceTimer = null;
  }

  Future<void> startService() async {
    _cancelStopServiceTimer();
    if (_serviceStarted) return;

    final alreadyRunning = await FlutterForegroundTask.isRunningService;
    if (alreadyRunning) {
      _serviceStarted = true;
      AppLogger.i('[FGService] Service already running — reconnected');
      _flushPending();
      return;
    }

    final result = await FlutterForegroundTask.startService(
      notificationTitle: _pendingData?['title'] ?? 'Meitorrent',
      notificationText: _pendingData?['text'] ?? 'Starting…',
      callback: torrentServiceCallback,
    );

    _serviceStarted = result is ServiceRequestSuccess ||
        await FlutterForegroundTask.isRunningService;
    AppLogger.i(
      '[FGService] Start result: ${_serviceStarted ? 'success' : 'failed'}',
    );

    if (_serviceStarted) _flushPending();
  }

  void _flushPending() {
    final data = _pendingData;
    if (data != null) {
      FlutterForegroundTask.updateService(
        notificationTitle: data['title'],
        notificationText: data['text'],
      );
      _pendingData = null;
    }
  }

  Future<void> stopService() async {
    _cancelStopServiceTimer();
    await NotificationService.instance.cancelAllActiveNotifications();
    await FlutterForegroundTask.stopService();
    _serviceStarted = false;
    _pendingData = null;
    _lastSummary = null;
    AppLogger.i('[FGService] Stopped');
  }

  DateTime? _lastPush;
  String? _lastSummary;
  final Set<String> _showingNotificationIds = {};

  void pushUpdate(List<TorrentStatus> statuses) {
    final currentIds = statuses.map((s) => s.id).toSet();
    final toCancel = _showingNotificationIds.difference(currentIds);
    for (final id in toCancel) {
      NotificationService.instance.cancelNotification(id);
    }
    _showingNotificationIds
      ..clear()
      ..addAll(currentIds);

    final active = statuses
        .where((t) => t.state.isActive && !t.isPaused && !t.isCompleted)
        .toList();
    final completed = statuses
        .where((t) => t.isCompleted || t.progress >= 1.0)
        .toList();
    final paused = statuses
        .where((t) => (t.isPaused || t.isStopped) && !t.isCompleted && t.progress < 1.0)
        .toList();

    if (active.isEmpty) {
      if (_serviceStarted && _stopServiceTimer == null) {
        _stopServiceTimer = Timer(const Duration(seconds: 10), () {
          if (_serviceStarted) stopService();
        });
      }
    } else {
      _cancelStopServiceTimer();
    }

    if (statuses.isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (_lastPush != null &&
        now.difference(_lastPush!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastPush = now;

    // 1. Stable notification ordering by addedAt and ID (never changes, zero jumping)
    active.sort((a, b) {
      final cmp = a.addedAt.compareTo(b.addedAt);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    // Scale: pick top 3 active torrents.
    final topActive = active.take(3).toList();
    final visibleIds = topActive.map((e) => e.id).toSet();

    for (final s in active) {
      if (!visibleIds.contains(s.id)) {
        NotificationService.instance.cancelNotification(s.id);
      }
    }

    // 2. Suppress paused notifications
    for (final s in paused) {
      NotificationService.instance.cancelNotification(s.id);
    }

    // 3. Show completed notifications
    for (final s in completed) {
      NotificationService.instance.showCompletionNotification(s);
    }

    // 4. Show active notifications (top 3)
    for (final s in topActive) {
      NotificationService.instance.showActiveNotification(s);
    }

    const String title = 'Meitorrent';
    final String text;

    if (active.isNotEmpty) {
      final totalDown = active.fold<int>(0, (s, t) => s + t.downloadSpeed);
      text = '${active.length} active · ↓ ${SpeedFormatter.format(totalDown)}';
    } else if (completed.isNotEmpty) {
      text =
          '${completed.length} download${completed.length == 1 ? '' : 's'} complete';
    } else if (paused.isNotEmpty) {
      text = '${paused.length} torrent${paused.length == 1 ? '' : 's'} paused';
    } else {
      text = 'No torrents added';
    }

    final payload = <String, dynamic>{
      'title': title,
      'text': text,
      'sessionAddress': TorrentEngineService.instance.sessionAddress,
      'savePath': TorrentEngineService.instance.defaultDownloadPath,
      'timestamps': Map.fromEntries(
        statuses.map((s) => MapEntry(s.id, s.addedAt.millisecondsSinceEpoch)),
      ),
    };

    if (!_serviceStarted && active.isNotEmpty) {
      _pendingData = payload;
      startService();
      return;
    }

    if (_lastSummary == text) return;
    _lastSummary = text;

    FlutterForegroundTask.sendDataToTask(payload);
  }

  bool get isRunning => _serviceStarted;
}
