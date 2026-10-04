import 'package:flutter/foundation.dart';

/// Centralized error and crash reporting.
/// In production, set [crashReportingCallback] (e.g. to Firebase Crashlytics
/// or Sentry) so errors are reported. Otherwise only debug logging is used.
class ErrorHandlingService {

  /// Optional callback for production crash reporting (Firebase Crashlytics, Sentry, etc.).
  /// Set from main() after WidgetsFlutterBinding.ensureInitialized().
  static void Function(dynamic exception, StackTrace? stackTrace)? crashReportingCallback;

  static void logError(dynamic exception, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('Error: $exception');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }

    // Production: send to crash reporting service when callback is set
    try {
      crashReportingCallback?.call(exception, stackTrace);
    } catch (_) {}
  }

  static void logInfo(String message) {
    if (kDebugMode) {
      print('Info: $message');
    }
  }

  static void logWarning(String message) {
    if (kDebugMode) {
      print('Warning: $message');
    }
  }
}
