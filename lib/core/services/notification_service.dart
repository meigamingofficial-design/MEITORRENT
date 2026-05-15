import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/torrent_status.dart';
import '../utils/speed_formatter.dart';
import '../utils/size_formatter.dart';
import 'folder_service.dart';

/// Immutable constants for Notification Action buttons.
abstract class NotificationActions {
  static const String pause = 'pause_torrent';
  static const String resume = 'resume_torrent';
  static const String stop = 'stop_torrent';
  static const String openFolder = 'open_folder';
}

/// Payload model representing a notification action event.
class NotificationActionEvent {
  final String actionId;
  final String torrentId;
  final String savePath;
  final String name;

  NotificationActionEvent({
    required this.actionId,
    required this.torrentId,
    required this.savePath,
    required this.name,
  });
}

/// Required top-level background notification responder.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) async {
  // Currently no background actions require special handling after removing Dismiss
}

/// Handles individual per-torrent notifications using flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Broadcast stream to dispatch action button presses to Riverpod state controllers.
  final _actionController = StreamController<NotificationActionEvent>.broadcast();
  Stream<NotificationActionEvent> get actionStream => _actionController.stream;

  /// Channel IDs for separate active and completed alerts.
  static const String _activeChannelId = 'meitorrent_active';
  static const String _completedChannelId = 'meitorrent_completed';

  /// Last time we updated each torrent's notification (keyed by torrent ID).
  final Map<String, DateTime> _lastUpdate = {};

  /// Last body string sent for each torrent — prevents identical OS calls.
  final Map<String, String> _lastBody = {};

  /// Currently active shown progress notification IDs.
  final Set<String> _activeNotificationIds = {};

  /// In-memory cache of notified completions for synchronous suppression.
  final Set<String> _notifiedCompletionsMemory = {};

  static const Duration _throttle = Duration(seconds: 2);

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        final actionId = details.actionId;
        if (payload != null) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final savePath = data['path'] as String;
            final name = data['name'] as String;
            final torrentId = data['id'] as String;

            if (actionId != null) {
              _actionController.add(NotificationActionEvent(
                actionId: actionId,
                torrentId: torrentId,
                savePath: savePath,
                name: name,
              ));
              if (actionId == NotificationActions.openFolder) {
                cancelNotification(torrentId);
              }
            } else {
              FolderService.instance.openDownloadTarget(
                savePath: savePath,
                name: name,
              );
              cancelNotification(torrentId);
            }
          } catch (_) {}
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _initialized = true;
  }

  int _notificationId(String torrentId) => torrentId.hashCode & 0x7fffffff;

  Future<bool> _hasNotifiedCompletion(String torrentId) async {
    if (_notifiedCompletionsMemory.contains(torrentId)) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('meitorrent_notified_completions') ?? [];
      if (list.contains(torrentId)) {
        _notifiedCompletionsMemory.add(torrentId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markCompletionNotified(String torrentId) async {
    _notifiedCompletionsMemory.add(torrentId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('meitorrent_notified_completions') ?? [];
      if (!list.contains(torrentId)) {
        list.add(torrentId);
        await prefs.setStringList('meitorrent_notified_completions', list);
      }
    } catch (_) {}
  }

  Future<void> clearCompletionNotified(String torrentId) async {
    _notifiedCompletionsMemory.remove(torrentId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('meitorrent_notified_completions') ?? [];
      if (list.contains(torrentId)) {
        list.remove(torrentId);
        await prefs.setStringList('meitorrent_notified_completions', list);
      }
    } catch (_) {}
  }

  Future<void> showActiveNotification(TorrentStatus status) async {
    if (!_initialized) await initialize();

    // Automatically clear completion tracking if torrent restarts downloading
    await clearCompletionNotified(status.id);

    final now = DateTime.now();
    final last = _lastUpdate[status.id];
    if (last != null && now.difference(last) < _throttle) return;
    _lastUpdate[status.id] = now;

    final progress = (status.progress * 100).toInt().clamp(0, 100);
    final sizeStr =
        '${SizeFormatter.format(status.downloadedBytes)} / ${SizeFormatter.format(status.totalSize)}';

    final String body;
    bool showProgress = false;

    if (status.state == TorrentState.downloadingMetadata) {
      body = 'Fetching metadata…';
    } else if (status.state == TorrentState.checkingFiles ||
        status.state == TorrentState.checkingResume ||
        status.state == TorrentState.allocating) {
      body = '${status.state.displayName} · $progress% ($sizeStr)';
      showProgress = true;
    } else {
      final speedStr = SpeedFormatter.format(status.downloadSpeed);
      final etaStr = status.etaSeconds != null
          ? ' · ${_formatEta(status.etaSeconds!)} left'
          : '';
      body = '$progress% · $sizeStr\n↓ $speedStr$etaStr';
      showProgress = true;
    }

    if (_lastBody[status.id] == body) return;
    _lastBody[status.id] = body;

    final notifId = _notificationId(status.id);
    _activeNotificationIds.add(status.id);

    final androidDetails = AndroidNotificationDetails(
      _activeChannelId,
      'Active Downloads',
      channelDescription: 'Shows active torrent download progress',
      importance: Importance.min,
      priority: Priority.min,
      showProgress: showProgress,
      maxProgress: 100,
      progress: progress,
      onlyAlertOnce: true,
      autoCancel: false,
      ongoing: true,
      visibility: NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationActions.pause,
          'Pause',
          showsUserInterface: true,
        ),
      ],
      when: status.addedAt.millisecondsSinceEpoch,
      showWhen: true,
    );

    await _plugin.show(
      notifId,
      status.name,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode({
        'path': status.savePath,
        'name': status.name,
        'id': status.id,
      }),
    );
  }

  Future<void> showCompletionNotification(TorrentStatus status) async {
    if (!_initialized) await initialize();

    if (await _hasNotifiedCompletion(status.id)) return;

    final notifId = _notificationId(status.id);
    _activeNotificationIds.remove(status.id);

    final body =
        '✓ Download complete · ${SizeFormatter.format(status.totalSize)}';

    final androidDetails = AndroidNotificationDetails(
      _completedChannelId,
      'Completed Downloads',
      channelDescription: 'Shows notifications for completed torrent downloads',
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
      autoCancel: true,
      ongoing: false,
      enableVibration: true,
      playSound: true,
      visibility: NotificationVisibility.private,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationActions.openFolder,
          'Open Folder',
          showsUserInterface: true,
        ),
      ],
      when: status.addedAt.millisecondsSinceEpoch,
      showWhen: true,
    );

    await _plugin.show(
      notifId,
      status.name,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode({
        'path': status.savePath,
        'name': status.name,
        'id': status.id,
      }),
    );

    await _markCompletionNotified(status.id);
  }

  Future<void> updateTorrentNotification(TorrentStatus status) async {
    if (status.state.isFinished) {
      await showCompletionNotification(status);
    } else if (status.state.isPausedState) {
      await cancelNotification(status.id);
    } else {
      await showActiveNotification(status);
    }
  }

  Future<void> cancelNotification(String torrentId) async {
    try {
      if (!_initialized) return;
      _lastUpdate.remove(torrentId);
      _lastBody.remove(torrentId);
      _activeNotificationIds.remove(torrentId);
      _notifiedCompletionsMemory.add(torrentId);

      final notifId = _notificationId(torrentId);
      await _plugin.cancel(notifId);
    } catch (_) {}
  }

  Future<void> cancelAllActiveNotifications() async {
    try {
      if (!_initialized) return;
      final List<String> idsToCancel = _activeNotificationIds.toList();
      for (final id in idsToCancel) {
        await cancelNotification(id);
      }
    } catch (_) {}
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}
