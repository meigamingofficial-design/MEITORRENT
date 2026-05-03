import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../core/utils/speed_formatter.dart';
import '../../domain/entities/torrent_status.dart';
import 'logger_service.dart';
import 'notification_service.dart';

// ─── Top-level entry point (required by flutter_foreground_task) ──────────────

/// This function runs in a separate isolate when the foreground service starts.
@pragma('vm:entry-point')
void torrentServiceCallback() {
  FlutterForegroundTask.setTaskHandler(TorrentTaskHandler());
}

// ─── Task handler ─────────────────────────────────────────────────────────────

/// Handles foreground service lifecycle events.
///
/// Uses PUSH-based notification updates:
/// The main isolate pushes state via [FlutterForegroundTask.sendDataToTask],
/// rather than polling on [onRepeatEvent].
class TorrentTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    AppLogger.i('[FGService] Started at $timestamp via $starter');
  }

  /// Called every 30s as a liveness heartbeat only — real updates come via data.
  @override
  void onRepeatEvent(DateTime timestamp) {
    // Intentionally minimal — only serves as a liveness heartbeat.
  }

  /// Called when the main isolate pushes data via [FlutterForegroundTask.sendDataToTask].
  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      final title = data['title'] as String? ?? 'Meitorrent';
      final text = data['text'] as String? ?? '';
      FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      AppLogger.d('[FGService] Summary notification updated: $text');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
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
  Map<String, String>? _pendingData;

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
      notificationText: _pendingData?['text'] ?? 'Ready to download',
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

  /// Push-based notification update.
  ///
  /// Behaviour:
  /// - Updates individual per-torrent notifications via [NotificationService]
  /// - Updates the foreground service summary notification
  /// - Throttled globally at 500 ms
  /// - Stores pending data when service is not yet started (no silent drops)
  /// - Skips OS call if summary content is unchanged
  void pushUpdate(List<TorrentStatus> statuses) {
    // ── 500 ms global throttle ───────────────────────────────────────
    final now = DateTime.now();
    if (_lastPush != null &&
        now.difference(_lastPush!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastPush = now;

    // ── Update individual notifications (self-throttled in NotificationService)
    for (final status in statuses) {
      NotificationService.instance.updateTorrentNotification(status);
    }

    // ── Build summary text ───────────────────────────────────────────
    final active = statuses.where((t) => t.state.isActive).toList();
    final finished = statuses.where((t) => t.state.isFinished).toList();

    const String title = 'Meitorrent';
    final String text;

    if (active.isNotEmpty) {
      final totalDown =
          active.fold<int>(0, (s, t) => s + t.downloadSpeed);
      text =
          '${active.length} active · ↓ ${SpeedFormatter.format(totalDown)}';
    } else if (finished.isNotEmpty) {
      text = '${finished.length} download${finished.length == 1 ? '' : 's'} completed';
    } else {
      text = 'Ready to download';
    }

    final payload = <String, String>{'title': title, 'text': text};

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
