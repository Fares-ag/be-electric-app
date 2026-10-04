import 'package:cmms_core/config/locator.dart';
import 'package:cmms_core/config/service_locator.dart';
import 'package:cmms_core/services/realtime_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await setupServiceLocator();
  });

  tearDownAll(() async {
    await resetServiceLocator();
  });

  group('RealtimeAnalyticsService lifecycle', () {
    test('stopListening is available without Supabase initialization', () {
      final service = sl<RealtimeAnalyticsService>();
      expect(() => service.stopListening(), returnsNormally);
    });

    test('public stream getters remain accessible after stopListening', () {
      final service = sl<RealtimeAnalyticsService>();
      service.stopListening();
      expect(service.kpiStream, isNotNull);
      expect(service.workOrdersSummaryStream, isNotNull);
    });
  });
}
