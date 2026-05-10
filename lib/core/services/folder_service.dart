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
  /// For single-file torrents (or folders containing exactly one file), this
  /// uses `open_filex` to trigger Android's native "Open with" chooser.
  /// For multi-file torrents, it opens the directory directly.
  Future<void> openDownloadTarget({
    required String savePath,
    required String name,
  }) async {
    try {
      final targetPath = (savePath.isEmpty) ? await StorageService.instance.getDownloadPath() : savePath;
      final file = File('$targetPath/$name');
      final directFolder = Directory('$targetPath/$name');

      // 1. If it's a file, open it directly using open_filex (triggers Android "Open with" chooser)
      if (file.existsSync()) {
        AppLogger.i('[Folder] Opening single file with open_filex: ${file.path}');
        await OpenFilex.open(file.path);
        return;
      }

      // 2. If it's a folder, check if it contains exactly one file (recursive)
      if (directFolder.existsSync()) {
        try {
          final entities = directFolder.listSync(recursive: true).whereType<File>().toList();
          if (entities.length == 1) {
            final singleFile = entities.first;
            AppLogger.i('[Folder] Folder contains a single file, opening with open_filex: ${singleFile.path}');
            await OpenFilex.open(singleFile.path);
            return;
          }
        } catch (_) {
          // Fallback to opening the directory directly if listSync fails
        }

        // Open the directory directly
        AppLogger.i('[Folder] Opening directory: ${directFolder.path}');
        await openDownloadFolder(directFolder.path);
        return;
      }

      // 3. Fallback to parent directory if direct target doesn't exist
      final parentDir = Directory(targetPath);
      if (parentDir.existsSync()) {
        AppLogger.i('[Folder] Target not found, opening parent directory: $targetPath');
        await openDownloadFolder(targetPath);
      } else {
        AppLogger.w('[Folder] Parent not found, opening root download folder');
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
