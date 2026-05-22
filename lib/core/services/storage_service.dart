import 'dart:io';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import 'logger_service.dart';

/// Fully Play Store–compliant storage service for Meitorrent.
///
/// Manages the primary download path and ensures directory integrity
/// without requesting restricted permissions.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _channel = MethodChannel('com.meigaming.meitorrent/storage');

  /// Primary download location:
  /// /storage/emulated/0/Download/Meitorrent
  String? _cachedPath;

  /// Returns the absolute path to the app-writable Meitorrent download folder.
  ///
  /// Uses MethodChannel to fetch the platform-correct external downloads base.
  Future<String> getDownloadPath() async {
    if (_cachedPath != null) {
      return _cachedPath!;
    }

    try {
      final String? base = await _channel.invokeMethod<String>(
        'getDownloadDirectory',
      );
      if (base == null) {
        throw StateError('Could not locate external storage directory');
      }

      final normalizedBase = base.replaceFirst(RegExp(r'/$'), '');
      _cachedPath = '$normalizedBase/${AppConstants.defaultDownloadDirName}';
      AppLogger.i('[Storage] Resolved download path: $_cachedPath');
      return _cachedPath!;
    } catch (e) {
      AppLogger.e('[Storage] Failed to resolve download path', error: e);
      final fallback =
          '${Directory.systemTemp.path}/${AppConstants.defaultDownloadDirName}';
      AppLogger.w('[Storage] Falling back to temp download path: $fallback');
      return fallback;
    }
  }

  /// Ensures the Meitorrent directory exists before downloading.
  ///
  /// On Android 10+, apps can create sub-folders in 'Download'
  /// without explicit permissions.
  Future<void> ensureDirectoryExists() async {
    final path = await getDownloadPath();
    final dir = Directory(path);
    if (!dir.existsSync()) {
      try {
        await dir.create(recursive: true);
        if (!dir.existsSync()) {
          throw StateError('Directory was not created: $path');
        }
        AppLogger.i('[Storage] Created download directory: $path');
      } catch (e) {
        AppLogger.e('[Storage] Could not create directory', error: e);
        rethrow;
      }
    }
  }
}
