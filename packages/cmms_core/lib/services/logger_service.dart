// Centralized Logging Service
//
// Provides structured logging with different log levels and optional
// integration with crash reporting services like Firebase Crashlytics.
//
// Usage:
// ```dart
// LoggerService.debug('User logged in', tag: 'Auth');
// LoggerService.info('Data synced successfully');
// LoggerService.warning('API rate limit approaching');
// LoggerService.error('Failed to load data', error: e, stackTrace: stack);
// ```

import 'package:flutter/foundation.dart';

/// Log levels for filtering and categorizing log messages
enum LogLevel {
  debug(0),
  info(1),
  warning(2),
  error(3),
  none(4);

  const LogLevel(this.value);
  final int value;
}

/// Centralized logging service with structured logging capabilities
class LoggerService {
  LoggerService();

  // Configuration
  static LogLevel _minimumLogLevel =
      kDebugMode ? LogLevel.debug : LogLevel.info;
  static bool _enableTimestamps = true;
  static bool _enableStackTraces = true;

  // Optional crash reporting callback (for Firebase Crashlytics integration)
  static Function(dynamic error, StackTrace? stackTrace)? _crashReporter;

  /// Configure the logger
  static void configure({
    LogLevel? minimumLogLevel,
    bool? enableTimestamps,
    bool? enableStackTraces,
    Function(dynamic error, StackTrace? stackTrace)? crashReporter,
  }) {
    if (minimumLogLevel != null) _minimumLogLevel = minimumLogLevel;
    if (enableTimestamps != null) _enableTimestamps = enableTimestamps;
    if (enableStackTraces != null) _enableStackTraces = enableStackTraces;
    if (crashReporter != null) _crashReporter = crashReporter;
  }

  /// Log a debug message (only in debug mode)
  ///
  /// Use for detailed debugging information that should not appear in production.
  ///
  /// Example:
  /// ```dart
  /// LoggerService.debug('User data: $userData', tag: 'UserService');
  /// ```
  static void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  /// Log an info message
  ///
  /// Use for general informational messages about application state.
  ///
  /// Example:
  /// ```dart
  /// LoggerService.info('Data sync completed', tag: 'SyncService');
  /// ```
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Log a warning message
  ///
  /// Use for potentially harmful situations that don't prevent operation.
  ///
  /// Example:
  /// ```dart
  /// LoggerService.warning('API rate limit at 80%', tag: 'ApiService');
  /// ```
  static void warning(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }

  /// Log an error message
  ///
  /// Use for error events that might still allow the application to continue.
  /// Optionally includes error object and stack trace.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   // risky operation
  /// } catch (e, stackTrace) {
  ///   LoggerService.error('Operation failed', error: e, stackTrace: stackTrace, tag: 'DataService');
  /// }
  /// ```
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );

    // Report to crash reporting service if configured
    if (_crashReporter != null && error != null) {
      try {
        _crashReporter!(error, stackTrace);
      } catch (e, st) {
        // Silently fail if crash reporter throws
        debugPrint('âš ï¸ Crash reporter failed: $e');
      }
    }
  }

  /// Internal logging implementation
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // Check if this log level should be printed
    if (level.value < _minimumLogLevel.value) return;

    // Build log message
    final buffer = StringBuffer();

    // Add timestamp
    if (_enableTimestamps) {
      buffer.write('[${DateTime.now().toIso8601String()}] ');
    }

    // Add log level emoji and name
    buffer.write(_getLevelPrefix(level));

    // Add tag if provided
    if (tag != null && tag.isNotEmpty) {
      buffer.write('[$tag] ');
    }

    // Add message
    buffer.write(message);

    // Print the main log message
    debugPrint(buffer.toString());

    // Add error details if provided
    if (error != null) {
      debugPrint('  â†³ Error: $error');
    }

    // Add stack trace if provided and enabled
    if (_enableStackTraces && stackTrace != null) {
      final stackLines =
          stackTrace.toString().split('\n').take(5); // First 5 lines
      for (final line in stackLines) {
        debugPrint('  â†³ $line');
      }
    }
  }

  /// Get emoji prefix for log level
  static String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'ðŸ” [DEBUG] ';
      case LogLevel.info:
        return 'âœ… [INFO] ';
      case LogLevel.warning:
        return 'âš ï¸ [WARNING] ';
      case LogLevel.error:
        return 'âŒ [ERROR] ';
      case LogLevel.none:
        return '';
    }
  }

  /// Log a network request (convenience method)
  static void logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (_minimumLogLevel.value > LogLevel.debug.value) return;

    debugPrint('ðŸŒ [HTTP] $method $url');
    if (headers != null && headers.isNotEmpty) {
      debugPrint('  â†³ Headers: $headers');
    }
    if (body != null) {
      debugPrint('  â†³ Body: $body');
    }
  }

  /// Log a network response (convenience method)
  static void logResponse({
    required int statusCode,
    required String url,
    dynamic body,
    Duration? duration,
  }) {
    if (_minimumLogLevel.value > LogLevel.debug.value) return;

    final emoji = statusCode >= 200 && statusCode < 300 ? 'âœ…' : 'âŒ';
    final durationText =
        duration != null ? ' (${duration.inMilliseconds}ms)' : '';

    debugPrint('$emoji [HTTP] $statusCode $url$durationText');
    if (body != null && kDebugMode) {
      debugPrint('  â†³ Response: $body');
    }
  }

  /// Log a user action (for analytics/debugging)
  static void logUserAction(String action, {Map<String, dynamic>? parameters}) {
    if (_minimumLogLevel.value > LogLevel.info.value) return;

    debugPrint('ðŸ‘¤ [USER ACTION] $action');
    if (parameters != null && parameters.isNotEmpty) {
      debugPrint('  â†³ Parameters: $parameters');
    }
  }

  /// Log a performance measurement
  static void logPerformance(String operation, Duration duration) {
    if (_minimumLogLevel.value > LogLevel.info.value) return;

    final emoji = duration.inMilliseconds < 1000 ? 'âš¡' : 'ðŸŒ';
    debugPrint('$emoji [PERFORMANCE] $operation: ${duration.inMilliseconds}ms');
  }

  /// Measure and log execution time of an operation
  static Future<T> measureAsync<T>(
    String operation,
    Future<T> Function() function,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await function();
      stopwatch.stop();
      logPerformance(operation, stopwatch.elapsed);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      error(
        '$operation failed after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Measure and log execution time of a synchronous operation
  static T measureSync<T>(String operation, T Function() function) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = function();
      stopwatch.stop();
      logPerformance(operation, stopwatch.elapsed);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      error(
        '$operation failed after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
