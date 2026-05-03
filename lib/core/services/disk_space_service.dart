import 'package:flutter/services.dart';

import '../services/logger_service.dart';

/// Queries available disk space via a native StatFs call.
/// Falls back to a generous assumption on error (e.g. running in tests).
class DiskSpaceService {
  DiskSpaceService._();
  static final DiskSpaceService instance = DiskSpaceService._();

  static const _channel = MethodChannel('com.meigaming.meitorrent/disk');

  /// Returns available bytes on the partition containing [path].
  /// If [path] is null, queries external storage (default download location).
  Future<int> getFreeDiskBytes({String? path}) async {
    try {
      final args = <String, dynamic>{};
      if (path != null) args['path'] = path;
      final result = await _channel.invokeMethod<int>('getFreeDiskBytes', args);
      return result ?? _fallback;
    } on MissingPluginException {
      // Running in test / non-Android environment
      AppLogger.d('[Disk] Platform channel not available — using fallback');
      return _fallback;
    } on PlatformException catch (e) {
      AppLogger.w('[Disk] getFreeDiskBytes error: ${e.message}');
      return _fallback;
    }
  }

  /// 10 GB fallback — avoids blocking downloads when we can't check.
  static const int _fallback = 10 * 1024 * 1024 * 1024;
}
