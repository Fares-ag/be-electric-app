import 'package:cmms_core/bootstrap/crash_reporting_setup.dart';
import 'package:cmms_core/services/error_handling_service.dart';
import 'package:cmms_core/services/logger_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ErrorHandlingService.crashReportingCallback = null;
  });

  group('configureProductionCrashReporting', () {
    test('registers crash callback when enabled', () {
      configureProductionCrashReporting(enabled: true);

      expect(ErrorHandlingService.crashReportingCallback, isNotNull);

      ErrorHandlingService.crashReportingCallback!(
        StateError('test crash'),
        StackTrace.current,
      );
    });

    test('clears crash callback when disabled', () {
      configureProductionCrashReporting(enabled: true);
      configureProductionCrashReporting(enabled: false);

      expect(ErrorHandlingService.crashReportingCallback, isNull);
    });
  });
}
