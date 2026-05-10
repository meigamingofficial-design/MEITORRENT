import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../domain/entities/torrent_status.dart';
import '../utils/speed_formatter.dart';
import '../utils/size_formatter.dart';
import 'folder_service.dart';

/// Handles individual per-torrent notifications using flutter_local_notifications.
///
/// Design decisions:
/// - One notification per torrent (ID = torrentId.hashCode & 0x7fffffff)
/// - Uses bitwise AND instead of modulo to avoid negative/collision issues
/// - Per-torrent 500 ms throttle map prevents notification spam
/// - Identical-content guard prevents redundant OS calls
/// - cancelNotification() called by repository on delete
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Last time we updated each torrent's notification (keyed by torrent ID).
  final Map<String, DateTime> _lastUpdate = {};

  /// Last body string sent for each torrent — prevents identical OS calls.
  final Map<String, String> _lastBody = {};

  static const Duration _throttle = Duration(milliseconds: 500);

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) {
          final parts = payload.split('|');
          if (parts.length == 2) {
            FolderService.instance.openDownloadTarget(
              savePath: parts[0],
              name: parts[1],
            );
          }
        }
      },
    );
    _initialized = true;
  }

  /// Converts a torrent's string ID to a safe Android notification integer ID.
  ///
  /// Uses bitwise AND with [0x7fffffff] (max positive int32) to guarantee:
  ///   - Always positive (no negative notification IDs)
  ///   - No modulo collision risk
  ///   - Deterministic — same ID always produces same notification slot
  int _notificationId(String torrentId) =>
      torrentId.hashCode & 0x7fffffff;

  /// Updates or creates a notification for a specific torrent.
  ///
  /// Throttled to 500 ms per torrent and deduplicated against last body.
  Future<void> updateTorrentNotification(TorrentStatus status) async {
    if (!_initialized) await initialize();

    // ── Per-torrent 500 ms throttle ─────────────────────────────────
    final now = DateTime.now();
    final last = _lastUpdate[status.id];
    if (last != null && now.difference(last) < _throttle) return;
    _lastUpdate[status.id] = now;

    // ── Build notification content ───────────────────────────────────
    final progress = (status.progress * 100).toInt().clamp(0, 100);
    final String body;
    bool showProgress = false;

    final sizeStr = '${SizeFormatter.format(status.downloadedBytes)} / ${SizeFormatter.format(status.totalSize)}';

    switch (status.state) {
      case TorrentState.downloading:
        final speedStr = SpeedFormatter.format(status.downloadSpeed);
        final etaStr = status.etaSeconds != null
            ? ' · ${_formatEta(status.etaSeconds!)} left'
            : '';
        body = '$progress% · $sizeStr · ↓ $speedStr$etaStr';
        showProgress = true;

      case TorrentState.seeding:
        body = 'Seeding · $sizeStr · ↑ ${SpeedFormatter.format(status.uploadSpeed)}';

      case TorrentState.finished:
        body = 'Completed ✔  —  ${SizeFormatter.format(status.totalSize)} · Tap to open';

      case TorrentState.paused:
        body = 'Paused · $progress% ($sizeStr)';

      case TorrentState.downloadingMetadata:
        body = 'Fetching metadata…';

      case TorrentState.checkingFiles:
      case TorrentState.checkingResume:
      case TorrentState.allocating:
        body = '${status.state.displayName} · $progress% ($sizeStr)';
        showProgress = true;

      case TorrentState.error:
        body = 'Error: ${status.errorMessage ?? "Unknown error"}';

      default:
        body = '${status.state.displayName} · $sizeStr';
    }

    // ── Identical-content guard ──────────────────────────────────────
    // Avoid redundant OS notification calls when nothing has changed.
    if (_lastBody[status.id] == body) return;
    _lastBody[status.id] = body;

    // ── Show / update notification ───────────────────────────────────
    final notifId = _notificationId(status.id);

    final isFinished = status.state == TorrentState.finished;
    
    final androidDetails = AndroidNotificationDetails(
      'torrent_individual',
      'Torrent Progress',
      channelDescription: 'Individual progress for each torrent',
      importance: isFinished ? Importance.high : Importance.low,
      priority: isFinished ? Priority.high : Priority.low,
      showProgress: showProgress,
      maxProgress: 100,
      progress: progress,
      onlyAlertOnce: true,
      autoCancel: false,
      enableVibration: isFinished,
      playSound: isFinished,
      // Keep ongoing only while actively downloading/checking — not for
      // completed or paused torrents so the user can dismiss them.
      ongoing: status.state.isActive,
      // 🔒 Prevent "Flip-Up & Flip-Down" Shuffle: Force stable sorting based on addedAt
      when: status.addedAt.millisecondsSinceEpoch,
      showWhen: false,
    );

    await _plugin.show(
      notifId,
      status.name,
      body,
      NotificationDetails(android: androidDetails),
      payload: '${status.savePath}|${status.name}',
    );
  }

  /// Cancels the notification for [torrentId].
  /// Called by the repository immediately on delete.
  Future<void> cancelNotification(String torrentId) async {
    if (!_initialized) return;
    _lastUpdate.remove(torrentId);
    _lastBody.remove(torrentId);
    await _plugin.cancel(_notificationId(torrentId));
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  String _formatEta(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}
