import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

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
      final directFile = File('$savePath/$name');
      if (directFile.existsSync()) {
        await _openFile(directFile.path);
        return;
      }

      final directFolder = Directory('$savePath/$name');
      if (directFolder.existsSync()) {
        await openDownloadFolder(directFolder.path);
        return;
      }

      await openDownloadFolder(savePath);
    } catch (e, st) {
      AppLogger.e(
        '[Folder] Failed to open download target',
        error: e,
        stack: st,
      );
    }
  }

  /// Opens the download directory or a specific sub-folder.
  Future<void> openDownloadFolder([String? specificPath]) async {
    try {
      final fallbackPath = await StorageService.instance.getDownloadPath();
      final path = (specificPath != null && specificPath.trim().isNotEmpty)
          ? specificPath
          : fallbackPath;

      // If the caller accidentally passes a file path, open the file directly.
      final file = File(path);
      if (file.existsSync()) {
        await _openFile(file.path);
        return;
      }

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
    }
  }

  Future<void> _openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type == ResultType.done) {
      AppLogger.i('[Folder] Successfully opened file: $path');
      return;
    }

    AppLogger.w(
      '[Folder] Failed to open file directly: $path (${result.type}: ${result.message})',
    );
  }
}
