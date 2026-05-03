/// Application-wide constants.
class AppConstants {
  AppConstants._();

  /// Default save directory name (appended to external storage).
  static const String defaultDownloadDirName = 'Meitorrent';

  /// Minimum free disk space before auto-pausing (100 MB).
  static const int minFreeDiskSpaceBytes = 100 * 1024 * 1024;

  /// DB snapshot write interval.
  static const Duration dbWriteInterval = Duration(seconds: 5);

  /// Engine status stream poll interval.
  static const Duration enginePollInterval = Duration(milliseconds: 500);

  /// App package name.
  static const String packageName = 'com.meigaming.meitorrent';

  /// Foreground service notification channel ID.
  static const String notificationChannelId = 'meitorrent_download';
}
