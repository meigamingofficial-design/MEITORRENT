import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logger/logger.dart';

/// Application-wide structured logger singleton.
/// 
/// Enhanced with Firebase Crashlytics for production monitoring.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Log a debug message (Local only)
  static void d(String message, {Object? error, StackTrace? stack}) {
    _logger.d(message, error: error, stackTrace: stack);
  }

  /// Log an info message (Local + Firebase Breadcrumb)
  static void i(String message, {Object? error, StackTrace? stack}) {
    _logger.i(message, error: error, stackTrace: stack);
    // Crashlytics logs are saved on the device and sent with the next crash.
    FirebaseCrashlytics.instance.log('[INFO] $message');
  }

  /// Log a warning (Local + Firebase Non-Fatal if error exists)
  static void w(String message, {Object? error, StackTrace? stack}) {
    _logger.w(message, error: error, stackTrace: stack);
    FirebaseCrashlytics.instance.log('[WARN] $message');
    if (error != null) {
      FirebaseCrashlytics.instance.recordError(error, stack, reason: 'Warning: $message');
    }
  }

  /// Log an error (Local + Firebase Non-Fatal)
  static void e(String message, {Object? error, StackTrace? stack}) {
    _logger.e(message, error: error, stackTrace: stack);
    FirebaseCrashlytics.instance.log('[ERROR] $message');
    FirebaseCrashlytics.instance.recordError(
      error ?? message,
      stack,
      reason: 'Caught Error: $message',
    );
  }

  /// Log a fatal error (Local + Firebase Fatal)
  static void wtf(String message, {Object? error, StackTrace? stack}) {
    _logger.f(message, error: error, stackTrace: stack);
    FirebaseCrashlytics.instance.log('[FATAL] $message');
    FirebaseCrashlytics.instance.recordError(
      error ?? message,
      stack,
      fatal: true,
      reason: 'Fatal Crash Triggered: $message',
    );
  }

  // ─── Custom Instrumentation ───────────────────────────────────────

  /// Record user ID for personalized support
  static void setUserId(String id) =>
      FirebaseCrashlytics.instance.setUserIdentifier(id);

  /// Track app-specific state for crash analysis
  static void setCustomKey(String key, Object value) {
    if (value is String) {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
    } else if (value is bool) {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
    } else if (value is int) {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
    } else if (value is double) {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
    }
  }

  /// Specialized instrumentation for Meitorrent
  static void updateTorrentStats({
    required int activeDownloads,
    required double freeDiskSpaceGB,
    required bool isBatteryOptimized,
  }) {
    setCustomKey('active_downloads', activeDownloads);
    setCustomKey('free_disk_gb', freeDiskSpaceGB);
    setCustomKey('is_battery_optimized', isBatteryOptimized);
  }
}
