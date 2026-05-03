import 'package:logger/logger.dart';

/// Application-wide structured logger singleton.
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

  static void d(String message, {Object? error, StackTrace? stack}) =>
      _logger.d(message, error: error, stackTrace: stack);

  static void i(String message, {Object? error, StackTrace? stack}) =>
      _logger.i(message, error: error, stackTrace: stack);

  static void w(String message, {Object? error, StackTrace? stack}) =>
      _logger.w(message, error: error, stackTrace: stack);

  static void e(String message, {Object? error, StackTrace? stack}) =>
      _logger.e(message, error: error, stackTrace: stack);

  static void wtf(String message, {Object? error, StackTrace? stack}) =>
      _logger.f(message, error: error, stackTrace: stack);
}
