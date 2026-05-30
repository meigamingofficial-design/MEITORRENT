import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      String basePath = savePath;
      if (basePath.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final customPath = prefs.getString('meitorrent_default_save_path');
        basePath = (customPath != null && customPath.isNotEmpty)
            ? customPath
            : await StorageService.instance.getDownloadPath();
      }

      // 🚀 Deep Dive: Try to open the specific torrent folder if it exists
      // Most torrents create a sub-folder named after themselves.
      final specificPath = '$basePath/$name';
      final specificDir = Directory(specificPath);

      if (specificDir.existsSync()) {
        AppLogger.i('[Folder] Opening specific torrent folder: $specificPath');
        await openDownloadFolder(specificPath);
      } else {
        // Fallback to base save path if sub-folder doesn't exist (single file torrents)
        final parentDir = Directory(basePath);
        if (parentDir.existsSync()) {
          AppLogger.i('[Folder] Opening base save path: $basePath');
          await openDownloadFolder(basePath);
        } else {
          AppLogger.w(
            '[Folder] Folder location not found, opening root download folder',
          );
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
      String fallbackPath;
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('meitorrent_default_save_path');
      if (customPath != null && customPath.isNotEmpty) {
        fallbackPath = customPath;
      } else {
        fallbackPath = await StorageService.instance.getDownloadPath();
      }

      final path = (specificPath != null && specificPath.trim().isNotEmpty)
          ? specificPath
          : fallbackPath;

      // Ensure the base app directory exists so the file manager has something to show
      final dir = Directory(path);
      if (!dir.existsSync()) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }

      final String? result = await _channel.invokeMethod<String>('openFolder', {
        'path': path,
      });

      switch (result) {
        case 'exact':
          AppLogger.i('[Folder] Successfully opened folder: $path');
        case 'chooser':
          AppLogger.w('[Folder] Opened fallback chooser for folder: $path');
        case 'settings':
          AppLogger.w(
            '[Folder] Opened system documents UI instead of exact folder: $path',
          );
        default:
          AppLogger.w(
            '[Folder] File manager did not open the requested folder: $path',
          );
      }
    } catch (e, st) {
      AppLogger.e(
        '[Folder] Failed to open download folder',
        error: e,
        stack: st,
      );
      rethrow;
    }
  }
}
