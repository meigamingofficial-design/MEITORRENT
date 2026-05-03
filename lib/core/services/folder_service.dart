import 'dart:io';

import 'package:flutter/services.dart';

import 'logger_service.dart';
import 'storage_service.dart';

/// Handles opening the system file manager at the correct location.
class FolderService {
  FolderService._();
  static final FolderService instance = FolderService._();

  static const _channel = MethodChannel('com.meigaming.meitorrent/files');

  /// Opens the torrent's final download target.
  ///
  /// For single-file torrents, this uses `open_filex` to open the file
  /// directly. For multi-file torrents, it falls back to the native folder
  /// handling path.
  Future<void> openDownloadTarget({
    required String savePath,
    required String name,
  }) async {
    try {
      final targetPath = (savePath.isEmpty) ? await StorageService.instance.getDownloadPath() : savePath;
      final directFolder = Directory('$targetPath/$name');
      
      if (directFolder.existsSync()) {
        await openDownloadFolder(directFolder.path);
      } else {
        final parentDir = Directory(targetPath);
        if (parentDir.existsSync()) {
          await openDownloadFolder(targetPath);
        } else {
          // Final fallback: try to open the root download folder at least
          await openDownloadFolder();
        }
      }
    } catch (e, st) {
      AppLogger.e(
        '[Folder] Failed to open download target',
        error: e,
        stack: st,
      );
      rethrow;
    }
  }

  /// Opens the download directory or a specific sub-folder.
  Future<void> openDownloadFolder([String? specificPath]) async {
    try {
      final fallbackPath = await StorageService.instance.getDownloadPath();
      final path = (specificPath != null && specificPath.trim().isNotEmpty)
          ? specificPath
          : fallbackPath;

      // Ensure the base app directory exists so the file manager has something to show
      await StorageService.instance.ensureDirectoryExists();

      final String? result = await _channel.invokeMethod<String>('openFolder', {
        'path': path,
      });

      switch (result) {
        case 'exact':
          AppLogger.i('[Folder] Successfully opened folder: $path');
          break;
        case 'chooser':
          AppLogger.w('[Folder] Opened fallback chooser for folder: $path');
          break;
        case 'settings':
          AppLogger.w(
            '[Folder] Opened system documents UI instead of exact folder: $path',
          );
          break;
        default:
          AppLogger.w(
              '[Folder] File manager did not open the requested folder: $path');
          break;
      }
    } catch (e, st) {
      AppLogger.e('[Folder] Failed to open download folder',
          error: e, stack: st);
      rethrow;
    }
  }
}
