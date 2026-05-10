import 'dart:io';

import 'package:flutter/services.dart';

import 'logger_service.dart';
import 'storage_service.dart';

/// Handles opening the system file manager at the correct location.
class FolderService {
  FolderService._();
  static final FolderService instance = FolderService._();

  static const _channel = MethodChannel('com.meigaming.meitorrent/files');

  /// Opens the torrent's final download target directory.
  /// 
  /// Navigates the system file manager directly to the folder containing the downloaded
  /// files (the torrent's savePath / file location).
  Future<void> openDownloadTarget({
    required String savePath,
    required String name,
  }) async {
    try {
      final targetPath = (savePath.isEmpty) ? await StorageService.instance.getDownloadPath() : savePath;
      final parentDir = Directory(targetPath);
      
      if (parentDir.existsSync()) {
        AppLogger.i('[Folder] Opening containing folder location: $targetPath');
        await openDownloadFolder(targetPath);
      } else {
        AppLogger.w('[Folder] Folder location not found, opening root download folder');
        await openDownloadFolder();
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
