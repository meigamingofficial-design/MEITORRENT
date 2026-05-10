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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    AppLogger.i('[FGService] Started at $timestamp via $starter');
  }

  /// Called when the main isolate pushes data via [FlutterForegroundTask.sendDataToTask].
  @override
  void onReceiveData(Object data) {
    _lastMainIsolateUpdate = DateTime.now();
    if (data is Map<String, dynamic>) {
      // 1. Update notification text
      final title = data['title'] as String? ?? 'Meitorrent';
      final text = data['text'] as String? ?? '';
      
      FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );

      // 2. Capture session address and save path for background polling
      final addr = data['sessionAddress'] as int?;
      final path = data['savePath'] as String?;

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

    AppLogger.i('[FGService] Attaching to native engine at 0x${_sessionAddress!.toRadixString(16)}');
    
    // Initialize our local engine instance in THIS isolate using the shared pointer
    lt.LibtorrentFlutter.attach(
      sessionAddress: _sessionAddress!,
      defaultSavePath: _savePath,
      pollInterval: const Duration(seconds: 1),
    );

    // Update notification from our own polling too
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Skip updating from background polling if the main isolate is actively pushing to prevent blinking / fighting
      if (_lastMainIsolateUpdate != null &&
          DateTime.now().difference(_lastMainIsolateUpdate!) < const Duration(seconds: 4)) {
        return;
      }

      final engine = lt.LibtorrentFlutter.instanceInternal;
      if (engine == null) return;

      final torrents = engine.torrents.values.toList();
      if (torrents.isEmpty) return;

      // Simple summary for notification (background isolate — TorrentInfo fields only)
      final active = torrents.where((t) => t.state.isActive && !t.isPaused).toList();
      // progress >= 1.0 is the only reliable completion signal in the bg isolate
      final finished = torrents.where((t) => t.progress >= 1.0).toList();
      final String text;
      if (active.isNotEmpty) {
        final totalDown = active.fold<int>(0, (s, t) => s + t.downloadRate);
        text = '${active.length} active · ↓ ${SpeedFormatter.format(totalDown)}';
      } else if (finished.isNotEmpty) {
        text = '${finished.length} download${finished.length == 1 ? '' : 's'} complete';
      } else {
        text = '${torrents.length} torrent${torrents.length == 1 ? '' : 's'} paused';
      }

      FlutterForegroundTask.updateService(
        notificationTitle: 'Meitorrent',
        notificationText: text,
      );
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Optional: could do additional polling or cleanup here
  }

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

  /// Must be called in [main()] before [runApp].
  static void initCommunicationPort() {
    FlutterForegroundTask.initCommunicationPort();
  }

  /// Requests notification permission and configures the foreground task.
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

  // ── Pending state (queued before service is ready) ────────────────────────
  Map<String, dynamic>? _pendingData;

  /// Starts the foreground service if not already running.
  Future<void> startService() async {
    if (_serviceStarted) return;

    // Check if Android already has our service running from a previous session.
    final alreadyRunning = await FlutterForegroundTask.isRunningService;
    if (alreadyRunning) {
      _serviceStarted = true;
      AppLogger.i('[FGService] Service already running — reconnected');
      // Flush pending data into the existing notification immediately.
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

  /// Stops the foreground service.
  Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
    _serviceStarted = false;
    _pendingData = null;
    _lastSummary = null;
    AppLogger.i('[FGService] Stopped');
  }

  DateTime? _lastPush;

  // Tracks last summary text to avoid sending identical data to the OS.
  String? _lastSummary;

  // Tracks currently active individual torrent notification IDs to clean up orphaned notifications.
  final Set<String> _showingNotificationIds = {};

  /// Push-based notification update.
  ///
  /// Behaviour:
  /// - Updates individual per-torrent notifications via [NotificationService]
  /// - Updates the foreground service summary notification
  /// - Throttled globally at 500 ms
  /// - Stores pending data when service is not yet started (no silent drops)
  /// - Skips OS call if summary content is unchanged
  void pushUpdate(List<TorrentStatus> statuses) {
    // ── Update individual notifications & Cancel obsolete ones ──────
    final currentIds = statuses.map((s) => s.id).toSet();
    final toCancel = _showingNotificationIds.difference(currentIds);
    for (final id in toCancel) {
      NotificationService.instance.cancelNotification(id);
    }
    _showingNotificationIds
      ..clear()
      ..addAll(currentIds);

    // ── 500 ms global throttle for summary notification and content updates ───────────────────────────────────────
    final now = DateTime.now();
    if (_lastPush != null &&
        now.difference(_lastPush!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastPush = now;

    for (final status in statuses) {
      NotificationService.instance.updateTorrentNotification(status);
    }

    // ── Build summary text ───────────────────────────────────
    final active = statuses.where((t) => t.state.isActive && !t.isPaused).toList();
    final finished = statuses.where((t) =>
        t.isCompleted ||
        t.progress >= 1.0 ||
        (t.totalSize > 0 && t.downloadedBytes >= t.totalSize)).toList();
    final paused = statuses.where((t) => t.isPaused || t.isStopped).toList();

    const String title = 'Meitorrent';
    final String text;

    if (active.isNotEmpty) {
      final totalDown = active.fold<int>(0, (s, t) => s + t.downloadSpeed);
      text = '${active.length} active · ↓ ${SpeedFormatter.format(totalDown)}';
    } else if (finished.isNotEmpty) {
      text = '${finished.length} download${finished.length == 1 ? '' : 's'} complete';
    } else if (paused.isNotEmpty) {
      text = '${paused.length} torrent${paused.length == 1 ? '' : 's'} paused';
    } else if (statuses.isNotEmpty) {
      text = '${statuses.length} torrent${statuses.length == 1 ? '' : 's'}';
    } else {
      text = 'No torrents added';
    }

    final payload = <String, dynamic>{
      'title': title,
      'text': text,
      'sessionAddress': TorrentEngineService.instance.sessionAddress,
      'savePath': TorrentEngineService.instance.defaultDownloadPath,
    };

    if (!_serviceStarted) {
      // ── Queue for when service comes up ──────────────────────────────
      _pendingData = payload;
      return;
    }

    // ── Identical-content guard ──────────────────────────────────────
    if (_lastSummary == text) return;
    _lastSummary = text;

    FlutterForegroundTask.sendDataToTask(payload);
  }

  bool get isRunning => _serviceStarted;
}
