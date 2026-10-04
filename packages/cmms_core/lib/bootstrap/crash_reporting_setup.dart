import 'package:flutter/foundation.dart';

import '../services/error_handling_service.dart';
import '../services/logger_service.dart';

/// Wires [ErrorHandlingService] and [LoggerService] crash callbacks.
///
/// Uses an in-process release logger until Firebase Crashlytics / Sentry is
/// integrated via the same callback hook.
void configureProductionCrashReporting({required bool enabled}) {
  if (!enabled) {
    ErrorHandlingService.crashReportingCallback = null;
    return;
  }

  void report(dynamic exception, StackTrace? stackTrace) {
    debugPrint('[CRASH] $exception');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  ErrorHandlingService.crashReportingCallback = report;
  LoggerService.configure(crashReporter: report);
}
