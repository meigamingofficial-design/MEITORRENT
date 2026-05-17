import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/torrent_status.dart';
import 'deep_link_service.dart';
import 'logger_service.dart';

/// Checks the system clipboard for a valid magnet URI.
///
/// Called on app foreground to offer "Add torrent from clipboard?" prompt.
class ClipboardService {
  ClipboardService._();
  static final ClipboardService instance = ClipboardService._();

  static const _keyLastMagnet = 'last_handled_magnet';
  String? _lastHandledMagnet;
  bool _initialized = false;

  /// Must be called at app startup.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastHandledMagnet = prefs.getString(_keyLastMagnet);
      _initialized = true;
      AppLogger.d(
          '[Clipboard] Initialized with last handled: ${_lastHandledMagnet?.substring(0, 20)}...');
    } catch (e) {
      AppLogger.e('[Clipboard] Init failed', error: e);
    }
  }

  /// Returns a validated magnet URI string from the clipboard, or null.
  /// Deduplicates: returns null if the magnet is the same as [_lastHandledMagnet],
  /// unless [force] is true.
  Future<String?> getMagnetFromClipboard({
    List<TorrentStatus> existingTorrents = const [],
    bool force = false,
  }) async {
    if (!_initialized) await init();

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && isValidMagnetUri(text)) {
        // 1. Check persistence deduplication
        if (!force && text == _lastHandledMagnet) return null;

        return text;
      }
    } catch (_) {
      // Clipboard access denied or unavailable — silently ignore.
    }
    return null;
  }

  /// Marks a magnet as handled so it won't be suggested again immediately.
  Future<void> markHandled(String magnet) async {
    _lastHandledMagnet = magnet;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastMagnet, magnet);
    } catch (e) {
      AppLogger.e('[Clipboard] Failed to persist handled magnet', error: e);
    }
  }
}
